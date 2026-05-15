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

// WIN32_LEAN_AND_MEAN and NOMINMAX are set globally via the top-level
// CMakeLists.txt - don't redefine them here (causes C4005 warnings on /W4).

// Define UNICODE before any Windows headers so the *W APIs are picked.
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <Windows.h>
// objbase.h brings in IUnknown / IStream which Gdiplus headers depend on.
// WIN32_LEAN_AND_MEAN strips <ole2.h> from Windows.h so we need this
// explicit include or every Gdiplus header errors out.
#include <objbase.h>
// shellapi.h provides ShellExecuteW. Also stripped by WIN32_LEAN_AND_MEAN.
#include <shellapi.h>
#include <gdiplus.h>
#include <dwmapi.h>
#include <shlwapi.h>
#include <shlobj.h>
#include <commctrl.h>
// WinHTTP for the auto-installer HTTPS client
#include <winhttp.h>
#pragma comment(lib, "winhttp.lib")
#include <regex>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <regex>
#include <string>
#include <thread>
#include <vector>

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "msimg32.lib")

namespace fs = std::filesystem;
using namespace Gdiplus;

// The Lua bundle is embedded as a Windows RCDATA resource at id 100.
// See cpp/loader/bundle.rc.
static const unsigned char* get_bundle(size_t& size_out) {
    HRSRC hres = FindResourceW(nullptr, MAKEINTRESOURCEW(100), RT_RCDATA);
    if (!hres) { size_out = 0; return nullptr; }
    HGLOBAL hg = LoadResource(nullptr, hres);
    if (!hg) { size_out = 0; return nullptr; }
    size_out = SizeofResource(nullptr, hres);
    return (const unsigned char*)LockResource(hg);
}

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

// ---------- Auto-installer (download Solara if no executor found) ----------

// Forward decl - defined further down with the click handler. We use it
// inside the installer so the user sees per-step progress instead of a
// silent multi-minute hang.
static void post_status(const std::wstring& text, COLORREF color);

// Parses a https URL into (host, path) wide strings. Returns false on
// malformed input.
static bool parse_url(const std::wstring& url, std::wstring& host_out,
                      std::wstring& path_out, INTERNET_PORT& port_out, bool& https_out) {
    https_out = true;
    port_out = INTERNET_DEFAULT_HTTPS_PORT;
    size_t scheme_end = url.find(L"://");
    if (scheme_end == std::wstring::npos) return false;
    std::wstring scheme = url.substr(0, scheme_end);
    if (scheme == L"http") { https_out = false; port_out = INTERNET_DEFAULT_HTTP_PORT; }
    size_t host_start = scheme_end + 3;
    size_t path_start = url.find(L'/', host_start);
    if (path_start == std::wstring::npos) {
        host_out = url.substr(host_start);
        path_out = L"/";
    } else {
        host_out = url.substr(host_start, path_start - host_start);
        path_out = url.substr(path_start);
    }
    // Strip port from host if present
    size_t colon = host_out.find(L':');
    if (colon != std::wstring::npos) {
        port_out = (INTERNET_PORT)_wtoi(host_out.c_str() + colon + 1);
        host_out = host_out.substr(0, colon);
    }
    return !host_out.empty();
}

// HTTPS GET via WinHTTP. Returns body bytes on success, empty on failure.
// Follows redirects automatically. Passes browser-shaped headers because
// most executor sites 403 the default WinHTTP UA.
static std::vector<uint8_t> http_get(const std::wstring& url,
                                     int timeout_sec = 30,
                                     DWORD* status_out = nullptr) {
    if (status_out) *status_out = 0;
    std::vector<uint8_t> out;
    std::wstring host, path;
    INTERNET_PORT port;
    bool https;
    if (!parse_url(url, host, path, port, https)) return out;

    HINTERNET hs = WinHttpOpen(
        L"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        L"(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
        WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, WINHTTP_NO_PROXY_NAME,
        WINHTTP_NO_PROXY_BYPASS, 0);
    if (!hs) return out;
    DWORD to_ms = timeout_sec * 1000;
    WinHttpSetTimeouts(hs, to_ms, to_ms, to_ms, to_ms);

    HINTERNET hc = WinHttpConnect(hs, host.c_str(), port, 0);
    if (!hc) { WinHttpCloseHandle(hs); return out; }

    DWORD flags = https ? WINHTTP_FLAG_SECURE : 0;
    HINTERNET hr = WinHttpOpenRequest(hc, L"GET", path.c_str(),
        nullptr, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, flags);
    if (!hr) { WinHttpCloseHandle(hc); WinHttpCloseHandle(hs); return out; }

    const wchar_t* hdrs =
        L"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,"
        L"image/avif,image/webp,*/*;q=0.8\r\n"
        L"Accept-Language: en-US,en;q=0.9\r\n"
        L"Accept-Encoding: identity\r\n"   // we don't decode gzip/brotli
        L"Upgrade-Insecure-Requests: 1\r\n";

    if (WinHttpSendRequest(hr, hdrs, (DWORD)-1L, WINHTTP_NO_REQUEST_DATA,
                           0, 0, 0) &&
        WinHttpReceiveResponse(hr, nullptr)) {
        if (status_out) {
            DWORD sz = sizeof(DWORD);
            WinHttpQueryHeaders(hr,
                WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                WINHTTP_HEADER_NAME_BY_INDEX, status_out, &sz,
                WINHTTP_NO_HEADER_INDEX);
        }
        DWORD avail = 0;
        while (WinHttpQueryDataAvailable(hr, &avail) && avail > 0) {
            size_t prev = out.size();
            out.resize(prev + avail);
            DWORD read = 0;
            WinHttpReadData(hr, out.data() + prev, avail, &read);
            if (read == 0) break;
            if (read < avail) out.resize(prev + read);
        }
    }

    WinHttpCloseHandle(hr);
    WinHttpCloseHandle(hc);
    WinHttpCloseHandle(hs);
    return out;
}

// Downloads a URL straight to a file. Returns true on success and the
// file is >= 200 KB and looks like a PE binary (MZ magic).
static bool download_and_validate(const std::wstring& url, const fs::path& dst) {
    DWORD status = 0;
    auto bytes = http_get(url, 90, &status);
    if (status < 200 || status >= 300) return false;
    if (bytes.size() < 200 * 1024) return false;
    if (bytes[0] != 'M' || bytes[1] != 'Z') return false;
    std::ofstream f(dst, std::ios::binary | std::ios::trunc);
    if (!f) return false;
    f.write((const char*)bytes.data(), (std::streamsize)bytes.size());
    return (bool)f;
}

// Returns every plausible .exe URL on a page. Tries multiple patterns
// (attribute values, JS string literals) because executor sites bury
// the real download in onclick handlers and JSON blobs, not bare hrefs.
// Output is de-duplicated and resolved to absolute URLs. Sets cf_blocked
// to true if the response looks like a Cloudflare challenge page.
struct ScrapeResult {
    std::vector<std::wstring> candidates;
    DWORD                     status      = 0;
    bool                      cf_blocked  = false;
    size_t                    bytes       = 0;
};

static ScrapeResult scrape_exe_candidates(const std::wstring& page_url) {
    ScrapeResult sr;
    auto html_bytes = http_get(page_url, 25, &sr.status);
    sr.bytes = html_bytes.size();
    if (html_bytes.empty()) return sr;
    std::string html((const char*)html_bytes.data(), html_bytes.size());

    // Cloudflare challenge - we can't run their JS, so flag and move on.
    if (html.find("cf-browser-verification") != std::string::npos ||
        html.find("cf-challenge") != std::string::npos ||
        (sr.status == 403 && html.find("cloudflare") != std::string::npos) ||
        html.find("Just a moment...") != std::string::npos) {
        sr.cf_blocked = true;
        return sr;
    }

    std::regex patterns[] = {
        std::regex(R"((?:href|src|data-href|data-url|data-link|data-download)\s*=\s*"([^"]+\.exe[^"]*)")",
                   std::regex::icase),
        std::regex(R"((?:href|src|data-href|data-url|data-link|data-download)\s*=\s*'([^']+\.exe[^']*)')",
                   std::regex::icase),
        std::regex(R"("(https?://[^"]+\.exe[^"]*)")",
                   std::regex::icase),
        std::regex(R"('(https?://[^']+\.exe[^']*)')",
                   std::regex::icase),
    };

    std::wstring host, path;
    INTERNET_PORT port; bool https;
    parse_url(page_url, host, path, port, https);
    std::wstring base = (https ? L"https://" : L"http://") + host;

    auto push = [&](const std::string& s) {
        std::wstring w(s.begin(), s.end());
        if (w.rfind(L"http", 0) == 0) {
            // absolute, keep
        } else if (w.rfind(L"//", 0) == 0) {
            w = std::wstring(L"https:") + w;
        } else if (!w.empty() && w[0] == L'/') {
            w = base + w;
        } else {
            return; // skip relative non-rooted
        }
        for (auto& e : sr.candidates) if (e == w) return;
        sr.candidates.push_back(w);
    };

    for (auto& re : patterns) {
        auto it = std::sregex_iterator(html.begin(), html.end(), re);
        auto en = std::sregex_iterator();
        for (; it != en; ++it) push((*it)[1].str());
    }
    return sr;
}

// Best-effort Defender exclusion for a folder. No-op without admin.
static void add_defender_exclusion(const std::wstring& path) {
    std::wstring cmd = L"-NoProfile -Command \"Add-MpPreference -ExclusionPath '"
                     + path + L"' -ErrorAction SilentlyContinue\"";
    SHELLEXECUTEINFOW sei{};
    sei.cbSize = sizeof(sei);
    sei.fMask  = SEE_MASK_FLAG_NO_UI | SEE_MASK_NOCLOSEPROCESS;
    sei.lpVerb = L"runas";   // requires elevation; silent failure if denied
    sei.lpFile = L"powershell";
    sei.lpParameters = cmd.c_str();
    sei.nShow = SW_HIDE;
    ShellExecuteExW(&sei);
    if (sei.hProcess) {
        WaitForSingleObject(sei.hProcess, 3000);
        CloseHandle(sei.hProcess);
    }
}

// Polls for an executor folder to appear (created by its installer).
static bool wait_for_folder(const fs::path& p, int seconds) {
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(seconds);
    while (std::chrono::steady_clock::now() < deadline) {
        std::error_code ec;
        if (fs::exists(p.parent_path(), ec)) return true;
        Sleep(2000);
    }
    return false;
}

// Multi-source auto-installer. Walks a list of executor landing pages,
// scrapes every .exe candidate, and tries each until one downloads as a
// valid PE and the installer creates its autoexec folder. Pushes status
// updates to the UI at every step so the user sees what's happening.
static std::wstring auto_install_executor() {
    struct Source {
        const wchar_t* name;
        const wchar_t* page;
        fs::path       folder;
    };
    auto LA = []() -> fs::path {
        wchar_t* p = _wgetenv(L"LOCALAPPDATA");
        return p ? fs::path(p) : fs::path(L".");
    };
    fs::path solara = LA() / L"Solara";

    Source sources[] = {
        {L"Solara", L"https://getsolara.dev/",          solara},
        {L"Solara", L"https://getsolara.dev/download",  solara},
        {L"Solara", L"https://www.getsolara.dev/",      solara},
        {L"Solara", L"https://getsolara.gg/",           solara},
        {L"Solara", L"https://solaraexecutor.com/",     solara},
    };

    fs::path temp_dir = (_wgetenv(L"TEMP") ? fs::path(_wgetenv(L"TEMP"))
                                            : fs::path(L".")) / L"rogblox-installer";
    std::error_code ec;
    fs::create_directories(temp_dir, ec);
    add_defender_exclusion(temp_dir.wstring());

    for (auto& src : sources) {
        add_defender_exclusion(src.folder.wstring());

        post_status(L"Fetching " + std::wstring(src.page) + L" ...", ui::WARN);
        auto sr = scrape_exe_candidates(src.page);

        if (sr.cf_blocked) {
            post_status(std::wstring(src.page) +
                        L"\nblocked by Cloudflare challenge - skipping",
                        ui::WARN);
            continue;
        }
        if (sr.status >= 400) {
            wchar_t buf[64];
            wsprintfW(buf, L"HTTP %u", sr.status);
            post_status(std::wstring(src.page) + L"\nreturned " + buf +
                        L" - skipping", ui::WARN);
            continue;
        }
        if (sr.candidates.empty()) {
            wchar_t buf[96];
            wsprintfW(buf, L"%u bytes, no .exe links found", (unsigned)sr.bytes);
            post_status(std::wstring(src.page) + L"\n" + buf + L" - skipping",
                        ui::WARN);
            continue;
        }

        wchar_t banner[80];
        wsprintfW(banner, L"Found %u download candidate(s) on %ls",
                  (unsigned)sr.candidates.size(), src.page);
        post_status(banner, ui::WARN);

        bool success = false;
        for (size_t i = 0; i < sr.candidates.size() && !success; ++i) {
            const std::wstring& url = sr.candidates[i];
            post_status(L"Downloading\n" + url, ui::WARN);

            fs::path installer = temp_dir /
                (std::wstring(src.name) + L"-installer.exe");
            if (!download_and_validate(url, installer)) {
                post_status(L"Download failed or not a valid .exe\nTrying next candidate...",
                            ui::WARN);
                continue;
            }

            post_status(L"Installer downloaded.\nLaunching - accept the UAC prompt if it appears.",
                        ui::WARN);
            SHELLEXECUTEINFOW sei{};
            sei.cbSize = sizeof(sei);
            sei.fMask  = SEE_MASK_NOCLOSEPROCESS;
            sei.lpVerb = L"open";
            sei.lpFile = installer.c_str();
            sei.lpParameters = L"/SILENT";
            sei.nShow = SW_SHOW;
            if (!ShellExecuteExW(&sei)) {
                post_status(L"Could not start the installer\n(possibly blocked by Defender / SmartScreen)",
                            ui::BAD);
                continue;
            }
            if (sei.hProcess) CloseHandle(sei.hProcess);

            post_status(L"Installer running. Waiting up to 3 minutes\nfor the autoexec folder to appear...",
                        ui::WARN);
            if (wait_for_folder(src.folder / L"autoexec", 180)) {
                Sleep(2500);
                success = true;
            } else {
                post_status(L"Installer never created the autoexec folder.\nTrying next candidate...",
                            ui::WARN);
            }
        }
        if (success) return src.name;
    }
    return L"";
}

static std::vector<std::wstring> install_bundle() {
    std::vector<std::wstring> installed;
    size_t bundle_size = 0;
    const unsigned char* bundle = get_bundle(bundle_size);
    if (!bundle || bundle_size == 0) return installed;
    for (auto& p : detect_installed_executors()) {
        std::error_code ec;
        fs::create_directories(p, ec);
        fs::path target = p / L"rogblox.lua";
        std::ofstream f(target, std::ios::binary | std::ios::trunc);
        if (!f) continue;
        f.write(reinterpret_cast<const char*>(bundle),
                (std::streamsize)bundle_size);
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

static void draw_rounded_filled(Graphics& gx, const RectF& r, REAL radius, Brush& brush) {
    GraphicsPath path;
    path.AddArc(r.X,                    r.Y,                    radius * 2, radius * 2, 180, 90);
    path.AddArc(r.X + r.Width - radius*2, r.Y,                  radius * 2, radius * 2, 270, 90);
    path.AddArc(r.X + r.Width - radius*2, r.Y + r.Height - radius*2, radius*2, radius*2, 0, 90);
    path.AddArc(r.X,                    r.Y + r.Height - radius*2, radius*2, radius*2, 90, 90);
    path.CloseFigure();
    gx.FillPath(&brush, &path);
}

static void draw_rounded_stroke(Graphics& gx, const RectF& r, REAL radius, Pen& pen) {
    GraphicsPath path;
    path.AddArc(r.X,                    r.Y,                    radius * 2, radius * 2, 180, 90);
    path.AddArc(r.X + r.Width - radius*2, r.Y,                  radius * 2, radius * 2, 270, 90);
    path.AddArc(r.X + r.Width - radius*2, r.Y + r.Height - radius*2, radius*2, radius*2, 0, 90);
    path.AddArc(r.X,                    r.Y + r.Height - radius*2, radius*2, radius*2, 90, 90);
    path.CloseFigure();
    gx.DrawPath(&pen, &path);
}

static Color from_colorref(COLORREF c, BYTE a = 255) {
    return Color(a, GetRValue(c), GetGValue(c), GetBValue(c));
}

// Draws an ambient gradient orb (soft radial glow).
static void draw_orb(Graphics& gx, REAL cx, REAL cy, REAL radius,
                     COLORREF color, BYTE peak_alpha) {
    GraphicsPath p;
    p.AddEllipse(cx - radius, cy - radius, radius * 2, radius * 2);
    PathGradientBrush brush(&p);
    brush.SetCenterPoint(PointF(cx, cy));
    brush.SetCenterColor(from_colorref(color, peak_alpha));
    Color surround[1] = { Color(0, 0, 0, 0) };
    int count = 1;
    brush.SetSurroundColors(surround, &count);
    gx.FillPath(&brush, &p);
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
        Graphics gx(mem);
        gx.SetSmoothingMode(SmoothingModeAntiAlias);
        gx.SetTextRenderingHint(TextRenderingHintClearTypeGridFit);

        // Background gradient
        LinearGradientBrush bg(
            PointF(0, 0), PointF((REAL)W, (REAL)H),
            from_colorref(ui::BG_TOP), from_colorref(ui::BG_BOTTOM));
        RectF full(0, 0, (REAL)W, (REAL)H);
        draw_rounded_filled(gx, full, (REAL)ui::CORNER, bg);

        // Ambient orbs
        draw_orb(gx, -40,  -40,  220, RGB(0x7C, 0x3A, 0xED), 140);
        draw_orb(gx, (REAL)W + 40, (REAL)H + 40, 200, RGB(0x22, 0xD3, 0xEE), 90);
        draw_orb(gx, (REAL)W,  -20,  140, RGB(0xFF, 0x4F, 0xB8), 60);

        // Window stroke
        Pen stroke(from_colorref(ui::STROKE), 1.0f);
        draw_rounded_stroke(gx, RectF(0.5f, 0.5f, (REAL)W - 1, (REAL)H - 1),
                             (REAL)ui::CORNER, stroke);

        // Glass card centered
        RectF card(40, 60, (REAL)(W - 80), (REAL)(H - 130));
        SolidBrush cardBrush(from_colorref(ui::CARD, 235));
        draw_rounded_filled(gx, card, 12.0f, cardBrush);
        draw_rounded_stroke(gx, card, 12.0f, stroke);

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
        gx.DrawString(L"ROGBLOX", -1, &logoFont, logoRect, &fmt, &logoBrush);

        Font subFont(&ff, 11, FontStyleRegular, UnitPixel);
        SolidBrush subBrush(from_colorref(ui::TEXT_SUB));
        RectF subRect(card.X, card.Y + 62, card.Width, 18);
        gx.DrawString(L"Roblox cheat hub - click Load",
                     -1, &subFont, subRect, &fmt, &subBrush);

        // Big "Load" button - hit-tested directly in WM_LBUTTONDOWN.
        RectF btnRect(card.X + 30, card.Y + 100, card.Width - 60, 50);
        Color a0, a1;
        if (g.btn_pressed) {
            a0 = Color(255, 0x80, 0x4A, 0xDD);
            a1 = Color(255, 0x55, 0x28, 0xB0);
        } else if (g.btn_hover) {
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
            RectF glow_r(btnRect.X - i, btnRect.Y - i,
                         btnRect.Width + 2 * i, btnRect.Height + 2 * i);
            SolidBrush glow(Color((BYTE)(8 + i * 4), 0xA0, 0x6C, 0xFF));
            draw_rounded_filled(gx, glow_r, 12.0f + i, glow);
        }
        draw_rounded_filled(gx, btnRect, 12.0f, btnBrush);

        Font bigFont(&ff, 18, FontStyleBold, UnitPixel);
        SolidBrush white(Color((ARGB)Color::White));
        RectF btnText = btnRect;
        // vertical center hack: shift down a couple px so caps look centered
        btnText.Y += 12;
        gx.DrawString(g.busy.load() ? L"Working..." : L"Load",
                     -1, &bigFont, btnText, &fmt, &white);

        // Status text
        Font statFont(&ff, 11, FontStyleRegular, UnitPixel);
        SolidBrush statBrush(from_colorref(g.status_color));
        RectF statRect(card.X + 16, card.Y + 162,
                       card.Width - 32, card.Height - 170);
        StringFormat statFmt; statFmt.SetAlignment(StringAlignmentCenter);
        gx.DrawString(g.status.c_str(), -1, &statFont, statRect, &statFmt, &statBrush);

        // Footer
        Font footFont(&ff, 10, FontStyleRegular, UnitPixel);
        SolidBrush dimBrush(from_colorref(ui::TEXT_DIM));
        StringFormat footFmtL; footFmtL.SetAlignment(StringAlignmentNear);
        StringFormat footFmtR; footFmtR.SetAlignment(StringAlignmentFar);
        RectF footL(16, (REAL)H - 24, 200, 18);
        RectF footR((REAL)W - 280 - 16, (REAL)H - 24, 280, 18);
        gx.DrawString(L"ROGBLOX v0.5.0 (C++ loader)", -1, &footFont, footL, &footFmtL, &dimBrush);
        gx.DrawString(L"press RightCtrl in-game",       -1, &footFont, footR, &footFmtR, &dimBrush);
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

// Marshal a status update from any thread back to the UI thread.
static void post_status(const std::wstring& text, COLORREF color) {
    auto* heap = new std::pair<std::wstring, COLORREF>(text, color);
    PostMessageW(g.hwnd, WM_APP + 1, 0, (LPARAM)heap);
}

static void run_load_action() {
    if (g.busy.exchange(true)) return;
    set_status(L"Working...", ui::TEXT_SUB);

    std::thread([]() {
        // 1. If no executor is present, try to auto-install Solara.
        auto folders = detect_installed_executors();
        std::wstring auto_installed;
        if (folders.empty()) {
            post_status(
                L"No executor detected. Downloading Solara now...\n"
                L"This may take a couple minutes - watch for UAC + the\n"
                L"installer window. Don't close this loader.",
                ui::WARN);
            auto_installed = auto_install_executor();
            folders = detect_installed_executors();
        }

        // 2. Install the bundled ROGBLOX script into every detected
        //    executor's autoexec folder.
        auto installed = install_bundle();

        // 3. Launch Roblox regardless of #2's outcome.
        bool launched = launch_roblox();

        std::wstring msg;
        COLORREF col;
        if (!installed.empty() && launched) {
            msg = L"Done. Cheat installed into ";
            for (size_t i = 0; i < installed.size(); ++i) {
                if (i > 0) msg += L", ";
                msg += installed[i];
            }
            if (!auto_installed.empty()) {
                msg += L".\nAuto-installed " + auto_installed + L". ";
            } else {
                msg += L". ";
            }
            msg += L"Roblox is launching - press RightCtrl in-game.";
            col = ui::GOOD;
        } else if (installed.empty() && launched) {
            msg = L"Roblox is launching, but no executor could be installed\n"
                  L"automatically. Install Solara / Wave / Xeno manually,\n"
                  L"then click Load again.";
            col = ui::WARN;
        } else if (!installed.empty()) {
            msg = L"Cheat installed but couldn't auto-launch Roblox.\n"
                  L"Open Roblox manually.";
            col = ui::WARN;
        } else {
            msg = L"Could not install the cheat or launch Roblox.\n"
                  L"Make sure you're online and try again.";
            col = ui::BAD;
        }

        post_status(msg, col);
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
