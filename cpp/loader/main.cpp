// rogblox-loader.exe
//
// Pure C++ Win32 + GDI+ loader. Single window, single "Load" button.
// On click:
//   1. Detects every installed executor's autoexec folder.
//   2. Writes the embedded ROGBLOX Lua bundle into each one.
//   3. Launches Roblox.
//
// Self-contained: the entire Lua bundle is baked in as a byte array
// (see bundle_data.cpp generated at build time by CMakeLists).
//
// Build:
//   cd cpp && cmake -S . -B build -A x64
//   cmake --build build --config Release
//   Outputs: cpp\build\loader\Release\rogblox-loader.exe

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#define UNICODE
#define _UNICODE

#include <Windows.h>
#include <gdiplus.h>
#include <dwmapi.h>
#include <shlwapi.h>
#include <shlobj.h>
#include <commctrl.h>

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <string>
#include <thread>
#include <vector>

#include "bundle_data.hpp"

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "msimg32.lib")

namespace fs = std::filesystem;
using namespace Gdiplus;

// ---------- Constants ----------

namespace ui {
    constexpr int      WIN_W       = 480;
    constexpr int      WIN_H       = 360;
    constexpr int      CORNER      = 14;
    constexpr COLORREF BG_TOP      = RGB(0x15, 0x14, 0x1E);
    constexpr COLORREF BG_BOTTOM   = RGB(0x07, 0x07, 0x10);
    constexpr COLORREF CARD        = RGB(0x1C, 0x1B, 0x28);
    constexpr COLORREF STROKE      = RGB(0x2C, 0x2C, 0x3D);
    constexpr COLORREF ACCENT_A    = RGB(0xA0, 0x6C, 0xFF);
    constexpr COLORREF ACCENT_B    = RGB(0x61, 0x31, 0xD9);
    constexpr COLORREF ACCENT_HOV  = RGB(0xB9, 0x8A, 0xFF);
    constexpr COLORREF TEXT_PRI    = RGB(0xEC, 0xEC, 0xF5);
    constexpr COLORREF TEXT_SUB    = RGB(0x9A, 0xA0, 0xAE);
    constexpr COLORREF TEXT_DIM    = RGB(0x5E, 0x63, 0x73);
    constexpr COLORREF GOOD        = RGB(0x5B, 0xE0, 0xA2);
    constexpr COLORREF WARN        = RGB(0xFF, 0xC6, 0x63);
    constexpr COLORREF BAD         = RGB(0xFF, 0x6E, 0x78);
}

// ---------- State ----------

struct AppState {
    HWND hwnd               = nullptr;
    bool dragging           = false;
    POINT drag_start        = {};
    POINT win_start         = {};
    std::wstring status     = L"Click Load.";
    COLORREF status_color   = ui::TEXT_SUB;
    std::atomic<bool> busy{false};
    bool btn_hover          = false;
    bool btn_pressed        = false;
};
static AppState g;
static ULONG_PTR g_gdiplus_token = 0;

// ---------- Utilities ----------

static std::vector<fs::path> executor_autoexec_paths() {
    auto env = [](const wchar_t* name) -> fs::path {
        wchar_t buf[MAX_PATH] = {};
        DWORD n = GetEnvironmentVariableW(name, buf, MAX_PATH);
        return n > 0 ? fs::path(buf) : fs::path();
    };
    fs::path L = env(L"LOCALAPPDATA");
    fs::path R = env(L"APPDATA");
    fs::path U = env(L"USERPROFILE");
    return {
        L / L"Solara"    / L"autoexec",
        R / L"Solara"    / L"autoexec",
        L / L"Wave"      / L"autoexec",
        R / L"Wave"      / L"AutoExecute",
        L / L"Xeno"      / L"autoexec",
        L / L"Delta"     / L"autoexec",
        L / L"Synapse X" / L"autoexec",
        L / L"Krnl"      / L"autoexec",
        R / L"Krnl"      / L"autoexec",
        L / L"Fluxus"    / L"autoexec",
        R / L"Fluxus"    / L"autoexec",
        L / L"Script-Ware" / L"Roblox" / L"autoexec",
        L / L"AWP"       / L"autoexec",
        U / L"Hydrogen"  / L"autoexec",
        L / L"CelerNB"   / L"autoexec",
    };
}

static std::vector<fs::path> detect_installed_executors() {
    std::vector<fs::path> found;
    for (auto& p : executor_autoexec_paths()) {
        std::error_code ec;
        if (fs::exists(p.parent_path(), ec)) found.push_back(p);
    }
    return found;
}

static std::vector<std::wstring> install_bundle() {
    std::vector<std::wstring> installed;
    for (auto& p : detect_installed_executors()) {
        std::error_code ec;
        fs::create_directories(p, ec);
        fs::path target = p / L"rogblox.lua";
        std::ofstream f(target, std::ios::binary | std::ios::trunc);
        if (!f) continue;
        f.write(reinterpret_cast<const char*>(ROGBLOX_BUNDLE),
                (std::streamsize)ROGBLOX_BUNDLE_SIZE);
        if (f) {
            // Use the executor folder name (one above autoexec) as the label
            installed.push_back(p.parent_path().filename().wstring());
        }
    }
    return installed;
}

static bool launch_roblox() {
    HINSTANCE r = ShellExecuteW(nullptr, L"open",
        L"roblox-player:1+launchmode:play", nullptr, nullptr, SW_SHOWNORMAL);
    if ((INT_PTR)r > 32) return true;
    r = ShellExecuteW(nullptr, L"open", L"roblox://", nullptr, nullptr, SW_SHOWNORMAL);
    return (INT_PTR)r > 32;
}

// ---------- Painting ----------

static void draw_rounded_filled(Graphics& g, const RectF& r, REAL radius, Brush& brush) {
    GraphicsPath path;
    path.AddArc(r.X,                    r.Y,                    radius * 2, radius * 2, 180, 90);
    path.AddArc(r.X + r.Width - radius*2, r.Y,                  radius * 2, radius * 2, 270, 90);
    path.AddArc(r.X + r.Width - radius*2, r.Y + r.Height - radius*2, radius*2, radius*2, 0, 90);
    path.AddArc(r.X,                    r.Y + r.Height - radius*2, radius*2, radius*2, 90, 90);
    path.CloseFigure();
    g.FillPath(&brush, &path);
}

static void draw_rounded_stroke(Graphics& g, const RectF& r, REAL radius, Pen& pen) {
    GraphicsPath path;
    path.AddArc(r.X,                    r.Y,                    radius * 2, radius * 2, 180, 90);
    path.AddArc(r.X + r.Width - radius*2, r.Y,                  radius * 2, radius * 2, 270, 90);
    path.AddArc(r.X + r.Width - radius*2, r.Y + r.Height - radius*2, radius*2, radius*2, 0, 90);
    path.AddArc(r.X,                    r.Y + r.Height - radius*2, radius*2, radius*2, 90, 90);
    path.CloseFigure();
    g.DrawPath(&pen, &path);
}

static Color from_colorref(COLORREF c, BYTE a = 255) {
    return Color(a, GetRValue(c), GetGValue(c), GetBValue(c));
}

// Draws an ambient gradient orb (soft radial glow).
static void draw_orb(Graphics& g, REAL cx, REAL cy, REAL radius,
                     COLORREF color, BYTE peak_alpha) {
    GraphicsPath p;
    p.AddEllipse(cx - radius, cy - radius, radius * 2, radius * 2);
    PathGradientBrush brush(&p);
    brush.SetCenterPoint(PointF(cx, cy));
    brush.SetCenterColor(from_colorref(color, peak_alpha));
    Color surround[1] = { Color(0, 0, 0, 0) };
    int count = 1;
    brush.SetSurroundColors(surround, &count);
    g.FillPath(&brush, &p);
}

static void paint_window(HWND hwnd) {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);

    RECT rc; GetClientRect(hwnd, &rc);
    int W = rc.right - rc.left;
    int H = rc.bottom - rc.top;

    // Double-buffer via memory DC
    HDC mem = CreateCompatibleDC(hdc);
    HBITMAP bmp = CreateCompatibleBitmap(hdc, W, H);
    HBITMAP old = (HBITMAP)SelectObject(mem, bmp);

    {
        Graphics g(mem);
        g.SetSmoothingMode(SmoothingModeAntiAlias);
        g.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

        // Background gradient
        LinearGradientBrush bg(
            PointF(0, 0), PointF((REAL)W, (REAL)H),
            from_colorref(ui::BG_TOP), from_colorref(ui::BG_BOTTOM));
        RectF full(0, 0, (REAL)W, (REAL)H);
        draw_rounded_filled(g, full, (REAL)ui::CORNER, bg);

        // Ambient orbs
        draw_orb(g, -40,  -40,  220, RGB(0x7C, 0x3A, 0xED), 140);
        draw_orb(g, (REAL)W + 40, (REAL)H + 40, 200, RGB(0x22, 0xD3, 0xEE), 90);
        draw_orb(g, (REAL)W,  -20,  140, RGB(0xFF, 0x4F, 0xB8), 60);

        // Window stroke
        Pen stroke(from_colorref(ui::STROKE), 1.0f);
        draw_rounded_stroke(g, RectF(0.5f, 0.5f, (REAL)W - 1, (REAL)H - 1),
                             (REAL)ui::CORNER, stroke);

        // Glass card centered
        RectF card(40, 60, (REAL)(W - 80), (REAL)(H - 130));
        SolidBrush cardBrush(from_colorref(ui::CARD, 235));
        draw_rounded_filled(g, card, 12.0f, cardBrush);
        draw_rounded_stroke(g, card, 12.0f, stroke);

        // ROGBLOX wordmark with gradient text
        FontFamily ff(L"Segoe UI");
        Font logoFont(&ff, 36, FontStyleBold, UnitPixel);
        StringFormat fmt; fmt.SetAlignment(StringAlignmentCenter);

        RectF logoRect(card.X, card.Y + 14, card.Width, 48);
        LinearGradientBrush logoBrush(
            PointF(logoRect.X, logoRect.Y),
            PointF(logoRect.X + logoRect.Width, logoRect.Y),
            Color(255, 0xDA, 0xB6, 0xFF),
            Color(255, 0xFF, 0x6B, 0xC8));
        g.DrawString(L"ROGBLOX", -1, &logoFont, logoRect, &fmt, &logoBrush);

        Font subFont(&ff, 11, FontStyleRegular, UnitPixel);
        SolidBrush subBrush(from_colorref(ui::TEXT_SUB));
        RectF subRect(card.X, card.Y + 62, card.Width, 18);
        g.DrawString(L"Roblox cheat hub - click Load",
                     -1, &subFont, subRect, &fmt, &subBrush);

        // Big "Load" button - hit-tested directly in WM_LBUTTONDOWN.
        RectF btnRect(card.X + 30, card.Y + 100, card.Width - 60, 50);
        Color a0, a1;
        if (::g.btn_pressed) {
            a0 = Color(255, 0x80, 0x4A, 0xDD);
            a1 = Color(255, 0x55, 0x28, 0xB0);
        } else if (::g.btn_hover) {
            a0 = from_colorref(ui::ACCENT_HOV);
            a1 = Color(255, 0x77, 0x45, 0xFF);
        } else {
            a0 = from_colorref(ui::ACCENT_A);
            a1 = from_colorref(ui::ACCENT_B);
        }
        LinearGradientBrush btnBrush(
            PointF(btnRect.X, btnRect.Y),
            PointF(btnRect.X + btnRect.Width, btnRect.Y + btnRect.Height),
            a0, a1);
        // Glow underlay (drop shadow approximation)
        for (int i = 6; i >= 0; --i) {
            RectF g_r(btnRect.X - i, btnRect.Y - i,
                      btnRect.Width + 2 * i, btnRect.Height + 2 * i);
            SolidBrush glow(Color((BYTE)(8 + i * 4), 0xA0, 0x6C, 0xFF));
            draw_rounded_filled(g, g_r, 12.0f + i, glow);
        }
        draw_rounded_filled(g, btnRect, 12.0f, btnBrush);

        Font bigFont(&ff, 18, FontStyleBold, UnitPixel);
        SolidBrush white(Color::White);
        RectF btnText = btnRect;
        // vertical center hack: shift down a couple px so caps look centered
        btnText.Y += 12;
        g.DrawString(::g.busy.load() ? L"Working..." : L"Load",
                     -1, &bigFont, btnText, &fmt, &white);

        // Status text
        Font statFont(&ff, 11, FontStyleRegular, UnitPixel);
        SolidBrush statBrush(from_colorref(::g.status_color));
        RectF statRect(card.X + 16, card.Y + 162,
                       card.Width - 32, card.Height - 170);
        StringFormat statFmt; statFmt.SetAlignment(StringAlignmentCenter);
        g.DrawString(::g.status.c_str(), -1, &statFont, statRect, &statFmt, &statBrush);

        // Footer
        Font footFont(&ff, 10, FontStyleRegular, UnitPixel);
        SolidBrush dimBrush(from_colorref(ui::TEXT_DIM));
        StringFormat footFmtL; footFmtL.SetAlignment(StringAlignmentNear);
        StringFormat footFmtR; footFmtR.SetAlignment(StringAlignmentFar);
        RectF footL(16, (REAL)H - 24, 200, 18);
        RectF footR((REAL)W - 280 - 16, (REAL)H - 24, 280, 18);
        g.DrawString(L"ROGBLOX v0.5.0 (C++ loader)", -1, &footFont, footL, &footFmtL, &dimBrush);
        g.DrawString(L"press RightCtrl in-game",       -1, &footFont, footR, &footFmtR, &dimBrush);
    }

    BitBlt(hdc, 0, 0, W, H, mem, 0, 0, SRCCOPY);
    SelectObject(mem, old);
    DeleteObject(bmp);
    DeleteDC(mem);

    EndPaint(hwnd, &ps);
}

// ---------- Button geometry helpers ----------

static RECT compute_load_button() {
    RECT rc; GetClientRect(g.hwnd, &rc);
    int W = rc.right - rc.left;
    int H = rc.bottom - rc.top;
    int cardX = 40, cardW = W - 80;
    int cardY = 60;
    int btnX  = cardX + 30;
    int btnY  = cardY + 100;
    int btnW  = cardW - 60;
    int btnH  = 50;
    return {btnX, btnY, btnX + btnW, btnY + btnH};
}

static bool point_in_rect(POINT p, RECT r) {
    return p.x >= r.left && p.x < r.right && p.y >= r.top && p.y < r.bottom;
}

// ---------- Click handler ----------

static void set_status(const std::wstring& text, COLORREF color) {
    g.status = text;
    g.status_color = color;
    InvalidateRect(g.hwnd, nullptr, FALSE);
}

static void run_load_action() {
    if (g.busy.exchange(true)) return;
    set_status(L"Installing...", ui::TEXT_SUB);

    std::thread([]() {
        auto installed = install_bundle();
        bool launched = launch_roblox();

        std::wstring msg;
        COLORREF col;
        if (!installed.empty() && launched) {
            msg = L"Done. Cheat installed into ";
            for (size_t i = 0; i < installed.size(); ++i) {
                if (i > 0) msg += L", ";
                msg += installed[i];
            }
            msg += L".\nRoblox is launching. Press RightCtrl in-game.";
            col = ui::GOOD;
        } else if (installed.empty() && launched) {
            msg = L"Roblox is launching, but no executor was detected.\n"
                  L"Install Solara / Wave / Xeno first; then click Load again.";
            col = ui::WARN;
        } else if (!installed.empty()) {
            msg = L"Cheat installed but couldn't auto-launch Roblox.\n"
                  L"Open Roblox manually.";
            col = ui::WARN;
        } else {
            msg = L"No executor detected and Roblox didn't launch.\n"
                  L"Make sure Roblox + an executor are installed.";
            col = ui::BAD;
        }

        // Marshal back to UI thread via PostMessage
        auto* heap = new std::pair<std::wstring, COLORREF>(std::move(msg), col);
        PostMessageW(g.hwnd, WM_APP + 1, 0, (LPARAM)heap);
        g.busy = false;
    }).detach();
}

// ---------- Window procedure ----------

static LRESULT CALLBACK wnd_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_CREATE: {
        // DWM rounded corners (Windows 11). Falls back gracefully on Win10.
        DWM_WINDOW_CORNER_PREFERENCE corner = DWMWCP_ROUND;
        DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE,
                              &corner, sizeof(corner));
        BOOL dark = TRUE;
        DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE,
                              &dark, sizeof(dark));
        // Drop shadow
        MARGINS m = {1, 1, 1, 1};
        DwmExtendFrameIntoClientArea(hwnd, &m);
        return 0;
    }

    case WM_APP + 1: {
        // Status update marshaled from worker thread
        auto* heap = (std::pair<std::wstring, COLORREF>*)lp;
        set_status(heap->first, heap->second);
        delete heap;
        return 0;
    }

    case WM_LBUTTONDOWN: {
        POINT p = {LOWORD(lp), HIWORD(lp)};
        RECT btn = compute_load_button();
        if (point_in_rect(p, btn) && !g.busy.load()) {
            g.btn_pressed = true;
            SetCapture(hwnd);
            InvalidateRect(hwnd, nullptr, FALSE);
        } else if (p.y < 30) {
            // Title bar drag
            g.dragging = true;
            g.drag_start = p;
            ClientToScreen(hwnd, &g.drag_start);
            RECT wr; GetWindowRect(hwnd, &wr);
            g.win_start = {wr.left, wr.top};
            SetCapture(hwnd);
        }
        return 0;
    }

    case WM_LBUTTONUP: {
        POINT p = {LOWORD(lp), HIWORD(lp)};
        if (g.btn_pressed) {
            g.btn_pressed = false;
            ReleaseCapture();
            RECT btn = compute_load_button();
            if (point_in_rect(p, btn)) run_load_action();
            InvalidateRect(hwnd, nullptr, FALSE);
        }
        if (g.dragging) {
            g.dragging = false;
            ReleaseCapture();
        }
        return 0;
    }

    case WM_MOUSEMOVE: {
        POINT p = {LOWORD(lp), HIWORD(lp)};
        if (g.dragging) {
            POINT screen = p;
            ClientToScreen(hwnd, &screen);
            int dx = screen.x - g.drag_start.x;
            int dy = screen.y - g.drag_start.y;
            SetWindowPos(hwnd, nullptr,
                         g.win_start.x + dx, g.win_start.y + dy,
                         0, 0, SWP_NOSIZE | SWP_NOZORDER);
        } else {
            RECT btn = compute_load_button();
            bool over = point_in_rect(p, btn);
            if (over != g.btn_hover) {
                g.btn_hover = over;
                SetCursor(LoadCursor(nullptr, over ? IDC_HAND : IDC_ARROW));
                InvalidateRect(hwnd, nullptr, FALSE);
            }
            // Track-leave so hover clears when cursor exits window
            TRACKMOUSEEVENT t = {};
            t.cbSize = sizeof(t);
            t.dwFlags = TME_LEAVE;
            t.hwndTrack = hwnd;
            TrackMouseEvent(&t);
        }
        return 0;
    }

    case WM_MOUSELEAVE:
        if (g.btn_hover) {
            g.btn_hover = false;
            InvalidateRect(hwnd, nullptr, FALSE);
        }
        return 0;

    case WM_SETCURSOR: {
        POINT p; GetCursorPos(&p); ScreenToClient(hwnd, &p);
        RECT btn = compute_load_button();
        if (point_in_rect(p, btn)) {
            SetCursor(LoadCursor(nullptr, IDC_HAND));
            return TRUE;
        }
        break;
    }

    case WM_KEYDOWN:
        if (wp == VK_ESCAPE) PostMessage(hwnd, WM_CLOSE, 0, 0);
        return 0;

    case WM_PAINT:
        paint_window(hwnd);
        return 0;

    case WM_ERASEBKGND:
        return 1;  // skip default erase (we do it in WM_PAINT)

    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

// ---------- Entry point ----------

int APIENTRY wWinMain(HINSTANCE hInst, HINSTANCE, LPWSTR, int nCmd) {
    GdiplusStartupInput gpInput;
    GdiplusStartup(&g_gdiplus_token, &gpInput, nullptr);

    INITCOMMONCONTROLSEX icc = {sizeof(icc), ICC_STANDARD_CLASSES};
    InitCommonControlsEx(&icc);

    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc   = wnd_proc;
    wc.hInstance     = hInst;
    wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
    wc.lpszClassName = L"ROGBLOXLoader";
    wc.style         = CS_HREDRAW | CS_VREDRAW;
    RegisterClassExW(&wc);

    int screenW = GetSystemMetrics(SM_CXSCREEN);
    int screenH = GetSystemMetrics(SM_CYSCREEN);
    int x = (screenW - ui::WIN_W) / 2;
    int y = (screenH - ui::WIN_H) / 2;

    g.hwnd = CreateWindowExW(
        WS_EX_LAYERED | WS_EX_TOPMOST,
        L"ROGBLOXLoader", L"ROGBLOX",
        WS_POPUP | WS_VISIBLE,
        x, y, ui::WIN_W, ui::WIN_H,
        nullptr, nullptr, hInst, nullptr);

    if (!g.hwnd) return 1;

    // Solid window (no per-pixel alpha)
    SetLayeredWindowAttributes(g.hwnd, 0, 255, LWA_ALPHA);
    SetWindowPos(g.hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    ShowWindow(g.hwnd, SW_SHOW);
    UpdateWindow(g.hwnd);

    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    GdiplusShutdown(g_gdiplus_token);
    return (int)msg.wParam;
}
