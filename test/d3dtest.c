/* Creates D3D11 and D3D12 devices, prints the adapter name and presents real frames. */
#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <stdio.h>
#include <dxgi1_4.h>
#include <d3d11.h>
#include <d3d12.h>

static LRESULT CALLBACK proc(HWND h, UINT m, WPARAM w, LPARAM l) { return DefWindowProcA(h, m, w, l); }

static HWND mkwin(void)
{
    WNDCLASSA wc = {0};
    wc.lpfnWndProc = proc; wc.lpszClassName = "d3dtest"; wc.hInstance = GetModuleHandleA(NULL);
    RegisterClassA(&wc);
    return CreateWindowA("d3dtest", "d3dtest", WS_OVERLAPPEDWINDOW|WS_VISIBLE, 100, 100, 640, 360, 0, 0, wc.hInstance, 0);
}

static void pump(void) { MSG m; while (PeekMessageA(&m, 0, 0, 0, PM_REMOVE)) { TranslateMessage(&m); DispatchMessageA(&m); } }

int main(void)
{
    HRESULT hr; HWND w = mkwin(); IDXGIFactory1 *f = NULL; IDXGIAdapter1 *a = NULL; DXGI_ADAPTER_DESC1 ad;
    hr = CreateDXGIFactory1(&IID_IDXGIFactory1, (void**)&f); printf("CreateDXGIFactory1 %08lx\n", hr); if (FAILED(hr)) return 1;
    if (SUCCEEDED(IDXGIFactory1_EnumAdapters1(f, 0, &a))) { IDXGIAdapter1_GetDesc1(a, &ad); printf("adapter: %ls vendor %04x\n", ad.Description, ad.VendorId); }

    { /* D3D11 */
        ID3D11Device *dev = NULL; ID3D11DeviceContext *ctx = NULL; IDXGISwapChain *sc = NULL; ID3D11Texture2D *bb = NULL; ID3D11RenderTargetView *rtv = NULL;
        DXGI_SWAP_CHAIN_DESC d = {0}; D3D_FEATURE_LEVEL fl = 0; int i; FLOAT col[4] = {0.1f, 0.6f, 0.2f, 1.0f};
        d.BufferCount = 2; d.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM; d.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        d.OutputWindow = w; d.SampleDesc.Count = 1; d.Windowed = TRUE; d.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
        hr = D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0, NULL, 0, D3D11_SDK_VERSION, &d, &sc, &dev, &fl, &ctx);
        printf("D3D11CreateDeviceAndSwapChain %08lx fl %x\n", hr, fl);
        if (SUCCEEDED(hr)) {
            IDXGISwapChain_GetBuffer(sc, 0, &IID_ID3D11Texture2D, (void**)&bb);
            hr = ID3D11Device_CreateRenderTargetView(dev, (ID3D11Resource*)bb, NULL, &rtv); printf("CreateRTV %08lx\n", hr);
            for (i = 0; i < 120 && SUCCEEDED(hr); i++) { pump(); ID3D11DeviceContext_ClearRenderTargetView(ctx, rtv, col); hr = IDXGISwapChain_Present(sc, 1, 0); }
            printf("D3D11 present loop %08lx frames %d\n", hr, i);
            ID3D11RenderTargetView_Release(rtv); ID3D11Texture2D_Release(bb); IDXGISwapChain_Release(sc); ID3D11DeviceContext_Release(ctx); ID3D11Device_Release(dev);
        }
    }
    { /* D3D12 */
        ID3D12Device *dev = NULL; ID3D12CommandQueue *q = NULL; ID3D12Fence *fence = NULL; D3D12_COMMAND_QUEUE_DESC qd = {0}; HANDLE ev;
        hr = D3D12CreateDevice((IUnknown*)a, D3D_FEATURE_LEVEL_12_0, &IID_ID3D12Device, (void**)&dev); printf("D3D12CreateDevice %08lx\n", hr);
        if (SUCCEEDED(hr)) {
            hr = ID3D12Device_CreateCommandQueue(dev, &qd, &IID_ID3D12CommandQueue, (void**)&q); printf("CreateCommandQueue %08lx\n", hr);
            hr = ID3D12Device_CreateFence(dev, 0, D3D12_FENCE_FLAG_NONE, &IID_ID3D12Fence, (void**)&fence); printf("CreateFence %08lx\n", hr);
            ev = CreateEventA(NULL, FALSE, FALSE, NULL);
            ID3D12CommandQueue_Signal(q, fence, 1);
            ID3D12Fence_SetEventOnCompletion(fence, 1, ev);
            printf("wait fence %lu\n", WaitForSingleObject(ev, 5000));
            ID3D12Fence_Release(fence); ID3D12CommandQueue_Release(q); ID3D12Device_Release(dev);
        }
    }
    printf("END\n");
    return 0;
}
