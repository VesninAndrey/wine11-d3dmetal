/* Creates a Vulkan instance through vulkan-1.dll and prints the physical devices. */
#include <windows.h>
#include <stdio.h>
typedef void *inst;
typedef struct { int sType; const void *pNext; unsigned flags; const void *app; unsigned nl; const char *const *l; unsigned ne; const char *const *e; } ci;
int main(void){
  HMODULE h = LoadLibraryA("vulkan-1.dll"); printf("vulkan-1.dll %p\n", h); if(!h) return 1;
  void *(WINAPI *gipa)(inst,const char*) = (void*)GetProcAddress(h,"vkGetInstanceProcAddr");
  int (WINAPI *create)(const ci*,void*,inst*) = gipa(NULL,"vkCreateInstance");
  ci c={0}; c.sType=1; inst i=0; int r=create(&c,NULL,&i); printf("vkCreateInstance %d\n", r); if(r) return 1;
  int (WINAPI *en)(inst,unsigned*,void**) = gipa(i,"vkEnumeratePhysicalDevices");
  void (WINAPI *prop)(void*,void*) = gipa(i,"vkGetPhysicalDeviceProperties");
  unsigned n=0; en(i,&n,NULL); void *d[8]; if(n>8)n=8; en(i,&n,d); printf("devices %u\n", n);
  for(unsigned k=0;k<n;k++){ static char b[4096]; prop(d[k],b); printf("device: %s\n", b+20); }
  printf("END\n"); return 0; }
