/* Decodes a video file through Media Foundation and counts the frames. */
#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <stdio.h>
#include <wchar.h>
int wmain(int argc, wchar_t **argv)
{
    IMFSourceReader *r = NULL; IMFMediaType *t = NULL; HRESULT hr; int frames = 0, bytes = 0, i;
    if (argc < 2) { wprintf(L"usage: mftest file\n"); return 1; }
    CoInitializeEx(NULL, COINIT_MULTITHREADED);
    hr = MFStartup(MF_VERSION, 0); printf("MFStartup %08lx\n", hr);
    hr = MFCreateSourceReaderFromURL(argv[1], NULL, &r); printf("MFCreateSourceReaderFromURL %08lx\n", hr); if (FAILED(hr)) return 1;
    MFCreateMediaType(&t);
    IMFMediaType_SetGUID(t, &MF_MT_MAJOR_TYPE, &MFMediaType_Video);
    IMFMediaType_SetGUID(t, &MF_MT_SUBTYPE, &MFVideoFormat_RGB32);
    hr = IMFSourceReader_SetCurrentMediaType(r, MF_SOURCE_READER_FIRST_VIDEO_STREAM, NULL, t); printf("SetCurrentMediaType %08lx\n", hr);
    for (i = 0; i < 300; i++)
    {
        DWORD flags = 0, idx = 0; LONGLONG ts = 0; IMFSample *s = NULL;
        hr = IMFSourceReader_ReadSample(r, MF_SOURCE_READER_FIRST_VIDEO_STREAM, 0, &idx, &flags, &ts, &s);
        if (FAILED(hr)) { printf("ReadSample %08lx\n", hr); break; }
        if (s) { DWORD len = 0; IMFMediaBuffer *b = NULL; IMFSample_ConvertToContiguousBuffer(s, &b); if (b) { IMFMediaBuffer_GetCurrentLength(b, &len); IMFMediaBuffer_Release(b); } bytes += len; frames++; IMFSample_Release(s); }
        if (flags & MF_SOURCE_READERF_ENDOFSTREAM) break;
    }
    printf("frames %d bytes %d\nEND\n", frames, bytes);
    return 0;
}
