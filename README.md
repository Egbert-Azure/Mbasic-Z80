# Microsoft Basic 5.2 as Z80 assembler

This is a 8080 to Z80 translation of Microsoft's MBASIC 5.2 for CP/M.

The 8080 assembler source can be downloaded from
[Winworldpc](https://winworldpc.com/product/microsoft-basic/80)

I wrote a Ruby script to translate 8080 mnemonics to (more readable
imho) Z80 mnemonics.

I also verified the correctness of the translation by running it
through a Z80 assembler, using [LINK.SUB](LINK.SUB) for linking.
