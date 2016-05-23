m4_include(`commons.m4')

_HEADER_HL1(`19-May-2016: Weird loop optimization')

<p>This is a simplest ever memcpy() function implementation:</p>

_PRE_BEGIN
void memcpy (unsigned char* dst, unsigned char* src, size_t cnt)
{
	size_t i;
	for (i=0; i&lt;cnt; i++)
		dst[i]=src[i];
};
_PRE_END

<p>At least MSVC 6.0 from the end of 1990s till MSVC 2013 can produce a really weird code (this listing is generated by MSVC 2013 x86):</p>

_PRE_BEGIN
_dst$ = 8						; size = 4
_src$ = 12						; size = 4
_cnt$ = 16						; size = 4
_memcpy	PROC
	mov	edx, DWORD PTR _cnt$[esp-4]
	test	edx, edx
	je	SHORT $LN1@f
	mov	eax, DWORD PTR _dst$[esp-4]
	push	esi
	mov	esi, DWORD PTR _src$[esp]
	sub	esi, eax
; ESI=src-dst, i.e., pointers difference
$LL8@f:
	mov	cl, BYTE PTR [esi+eax] ; load byte at "esi+dst" or at "src-dst+dst" at the beginning or at just "src"
	lea	eax, DWORD PTR [eax+1] ; dst++
	mov	BYTE PTR [eax-1], cl   ; store the byte at "(dst++)--" or at just "dst" at the beginning
	dec	edx                    ; decrement counter until we finished
	jne	SHORT $LL8@f
	pop	esi
$LN1@f:
	ret	0
_memcpy	ENDP
_PRE_END

<p>
This is weird, because how humans work with two pointers? They store two addresses in two registers or two memory cells.
MSVC compiler in this case stores two pointers as one pointer (<b>sliding dst</b> in EAX) and difference between <b>src</b> and <b>dst</b> pointers (left unchanged over the span of loop body execution in ESI).
When it needs to load a byte from <b>src</b>, it loads it at <b>diff + sliding dst</b> and stores byte at just <b>sliding dst</b>.
</p>

<p>This is probably some optimization trick. But I've rewritten this function to:</p>

_PRE_BEGIN
_f2	PROC
	mov	edx, DWORD PTR _cnt$[esp-4]
	test	edx, edx
	je	SHORT $LN1@f
	mov	eax, DWORD PTR _dst$[esp-4]
	push	esi
	mov	esi, DWORD PTR _src$[esp]
	; eax=dst; esi=src
$LL8@f:
	mov	cl, BYTE PTR [esi+edx]
	mov	BYTE PTR [eax+edx], cl
	dec	edx
	jne	SHORT $LL8@f
	pop	esi
$LN1@f:
	ret	0
_f2	ENDP
_PRE_END

<p>... and it works as efficient as the <i>optimized</i> version on my Intel Xeon E31220 @ 3.10GHz.
Maybe, this optimization was targeted some older x86 CPUs of 1990s era, since this trick is used at least by ancient MS VC 6.0?</p>

<p>Any idea?</p>

<p>Hex-Rays 6.8 have a hard time recognizing patterns like that (hopefully, temporary?):</p>

_PRE_BEGIN
void __cdecl f1(char *dst, char *src, size_t size)
{
  size_t counter; // edx@1
  char *sliding_dst; // eax@2
  char tmp; // cl@3

  counter = size;
  if ( size )
  {
    sliding_dst = dst;
    do
    {
      tmp = (sliding_dst++)[src - dst];         // difference (src-dst) is calculated once, before loop body
      *(sliding_dst - 1) = tmp;
      --counter;
    }
    while ( counter );
  }
}
_PRE_END

<p>Nevertheless, this optimization trick is often used by MSVC (not just in DIY homebrew memcpy() routines, but in many loops which uses two or more arrays),
so it's worth for reverse engineers to keep it in mind.</p>

<!-- As of why writting occurred after <b>dst</b> incrementing? -->

_BLOG_FOOTER_GITHUB(`weird_loop_optimization')

_BLOG_FOOTER()
