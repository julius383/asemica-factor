# Asemica 

This is a re-implementation of [asemica](https://github.com/linenoise/asemica) which is a cipher that uses a document as a key.
The original is written in Perl and this one uses the [Factor Programming Language](https://factorcode.org/).

## Usage

To use this program you need to first have Factor installed on your
system. Clone the repository and change into the directory. The you can run it through invoking the factor-vm with `asemica.factor` and all the
necessary arguments for example on Arch Linux.

```
$ echo "Attack at Dawn" | factor-vm asemica.factor -m enc -c metamorphosis.txt -o enc.txt

$ cat enc.txt
they must request a little way he didn't know just getting weaker
and fur He began their skirts she fled onto her breast His bed
perhaps expected said nothing unusual was something of luxury For the
bedding was something of rain could think it had at all to sleeping a
COPYRIGHTED

$ factor-vm asemica.factor -m dec -c https://www.gutenberg.org/cache/epub/5200/pg5200.txt -i enc.txt
Attack at Dawn
```

The above encodes the message from stdin "Attack at Dawn" and prints out
the result on `STDOUT`. A file can be passed for the input and output
using `-i` and `-o`. Additionally the key file (`-c` argument) may be
a URL to an online file which.

## Practical Information

The program takes some time to start-up so it may be beneficial to
generate a custom image containing all the loaded libraries and
passing it as an argument. To do this run the following commands

```
$ factor-vm -run=readline-listener

IN: scratchpad USE: vocabs.loader
IN: scratchpad "/path/to/repo/" add-vocab-root
IN: scratchpad USE: asemica-factor
IN: scratchpad "/some/path/cust.img" save-image-and-exit
```

Afterwards make sure to add `-i=/some/path/cust.img` to calls to the
factor vm. Alternatively you can add a shebang line to the top of 
`asemica.factor` so you can run the program as a script. Running asemica
without any arguments prints out the usage.

```
asemica - a markov chain based cipher

usage: asemica -m mode -c <file/url> [-i <file>] [-o <file>]

Options:
  -m  either 'enc' or 'dec' for encode or decode mode
  -c  specify the corpus file or url
  -i  specify the input file (defaults to STDIN)
  -o  specify the output file (defaults to STDOUT)

```
