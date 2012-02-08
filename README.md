## BUILDING FROM SOURCE

This project was developed with Lazarus-0.9.31 and FPC-2.4.2

It should be possible to also build it with the stable
release of Lazarus-0.9.30, it does not use any things
that are specific to the very latest SVN release, at least
not to my knowledge and not intentionally.

To build it from source open the project file linuxastrocam.lpi 
with Lazarus and from the menu select Run -> Build. 
This should give you the excutable binary.


## PROBLEMS

I have tested it only on i386, the program makes a few
hardcoded assumptions about how GTK2 stores raw bitmaps
and this might lead to unexpected results on 64 bit
machines or if you have a different endianness. Please
leave me a message (or provide a patch if you can) if you
encounter such portbility problems. Since I could not 
test it myself anyways I did not even try to write code
for different architectures.

V4l2 will be accessed through libv4l1 (using the v4l1
potocol). This should work even if there is no v4l1
support in the kernel aymore, but I could not test this
because I am still using a v4l1 camera and an old kernel.
Eventually I might port it to V4l2 some day using the 
v4l2 component from the 5dpo project.

This program is only a dirty hack to make some things
easier for me, don't expect me to add every feature you
might suggest. The main reason why I uploaded this on
github was to document for other Pascal programmers 
how to access v4l1 devices and how I managed to create 
FITS files. 


