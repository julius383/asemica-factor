USING: accessors ascii assocs command-line http.client formatting
io io.encodings.utf8 io.files io.files.temp io.pathnames
kernel locals math math.parser math.ranges multiline
namespaces random regexp sequences sequences.repeating sets
splitting strings system vectors wrap.strings ;
IN: asemica 

TUPLE: transition
{ token      string }  ! Raw string that appeared
{ seen       integer } ! how many times token has been seen
{ door       vector }  ! words after this one in document key
{ doors      integer } ! length of door vector
{ exits      assoc }   ! words after plus occur count
meaningful             ! true or false depending if doors > 15
;

: <transition> ( -- transition )
    transition new
    "" >>token 
    0 >>seen
    16 <vector> >>door
    0 >>doors
    { } >alist >>exits 
    f >>meaningful ;

:: assoc-add ( val key assoc -- assoc ) 
    key assoc at
    [ drop val key assoc set-at assoc ]
    [ assoc { key val } suffix ]
    if* ;

:: add-or-increment ( key assoc -- assoc ) 
    key assoc at 
    [ 1 + key assoc set-at assoc ] 
    [ assoc { 1 } key prefix suffix ]
    if* ;

: clean-string ( str -- str )
   R/ \n/ " " re-replace
   R/ [^\w\']/ " " re-replace
   R/ \d/ " " re-replace
   R/ \s+/ " " re-replace
   R/ ^\s+/ "" re-replace
   R/ \s+$/ "" re-replace ;

: 2tokens ( str -- a b )
    clean-string " " split dup rest ;

! create a binary string padded with x 0s
: bin-pad ( x n -- str )
    >bin dup [ swap ] dip length - "0" swap repeat swap append ;

: zero-pad ( str x -- str ) 
    [ dup length ] dip swap - "0" swap repeat swap append ;

! transform a string of characters into a concatenated binary string
: unpack ( str -- newstr )
    [ >bin 8 zero-pad reverse ] { } map-as "" join ;

! transform a concatenated binary string into a character string
:: pack ( str -- seq )
   0 str length 8 <range> [
        :> start
        start 8 + :> end 
        end str length >
        [ str length ] [ end ] if
        start swap str subseq reverse bin>
   ] { } map-as but-last >string ;

! turn a number into a at least length 4 binary string
: make-nibble ( n -- str ) 
    >bin dup length 4 < [ 4 zero-pad ] when ;

! group a sequence into 4s
:: nibbles ( seq -- newseq )
    0 seq length 1 - 4 <range> [
        :> start
        start 4 + :> end 
        end seq length >
        [ seq length ] [ end ] if
        start swap seq subseq bin>
    ] { } map-as ;

: safe-random ( n -- n ) 
    dup random 2dup = [ nip 1 - ] [ nip ] if ;

: new-or-existing ( key assoc -- obj )
    at [
        <transition>
    ] unless* ;

: set-meaningful ( assoc -- newassoc )
    [ dup doors>> 15 > [ t >>meaningful ] when ]
    assoc-map ;

: update-transition-info ( value transition -- transition )
    2dup exits>> add-or-increment >>exits 
    dup [ door>> ?adjoin ] dip swap [ [ 1 + ] change-doors ]
    when [ 1 + ] change-seen ;

:: generate-transitions ( a b -- table )
    { } >alist :> ttable! ! create transition table
    a b ! tokens
    [
        :> value
        :> key
        ! get transition tuple if it exists or make new one
        key >lower ttable new-or-existing
        key >>token
        ! update with information
        value swap update-transition-info
        ! modify the transition table
        key >lower ttable assoc-add ttable!
    ] 2each ttable set-meaningful ;

: tokenize-corpus ( filename -- a b )
    utf8 file-contents 2tokens ;

:: encode ( message transitions tokens -- encmessage )
    tokens length safe-random tokens nth :> token! 
    "" :> encmessage!
    message unpack nibbles :> nbs!
    [ nbs empty? ] [ 
        { encmessage token " " } concat encmessage!
        token >lower transitions at meaningful>>
        [
            nbs unclip
            token >lower transitions at door>>
            nth token!
            nbs!
        ]
        [
         token >lower transitions at doors>> safe-random
         token >lower transitions at door>> nth token!
        ] if
    ] until { encmessage token " " } concat ;

: at-nth ( i words transitions -- transition )
    [ nth ] dip [ >lower ] dip at ;

:: decode ( input transitions tokens -- decmessage )
    "" :> decoded!
    input clean-string " " split :> words
    words length 1 - <iota> [
        :> i
        i words transitions at-nth meaningful>>
        [  
            i words transitions at-nth door>> [ 
                >lower i 1 + words nth >lower =
            ] find 
            :> elt
            :> idx
            elt [ idx make-nibble decoded swap append decoded! ] when
        ] when
    ] each decoded pack ;


: print-usage ( -- ) [[
asemica - a markov chain based cipher

usage: asemica -m mode -c <file/url> [-i <file>] [-o <file>]

Options:
  -m  either 'enc' or 'dec' for encode or decode mode
  -c  specify the corpus file or url
  -i  specify the input file (defaults to STDIN) 
  -o  specify the output file (defaults to STDOUT)
]] print ;

: make-relative ( path -- path' )
    dup absolute-path?
    [ current-directory get swap append-path ] unless ;

! retrieve the value of a specificed argument from an argument
! list
:: get-argument ( required name args -- value/f )
    args [ name = ] find over 
    [   ! argument flag was passed
        drop dup 1 + args length <
        [ 1 + args nth ]
        [   ! argument itself is missing
            name "Argument value for '%s' empty" printf
            print-usage flush 1 exit
        ]
        if
    ]
    [   ! argument flag missing now check it it is required
        required not
        [ 2drop f ]
        [ 
            name "Argument '%s' not passed" printf
            print-usage flush 1 exit
        ] if
    ] if ;

! try to get input from file, download from web or stdin
: get-input ( path/f -- str )
    [
        dup R/ ^http/ re-contains?
        [
            "corp.txt" temp-file dup [ download-to ] dip
        ]
        when make-relative utf8 <file-reader> stream-contents
    ]
    [
       contents ! read input from stdin
    ]
    if* ;

! write output to file or print to stdout
: write-output ( path/f str -- )
    70 wrap-string swap 
    [ [ "\n" split ] dip make-relative utf8 set-file-lines ]
    [ print ] if* ;

:: (run) ( args -- )
    args length 0 = [ print-usage flush 1 exit ] when  
    t "-m" args get-argument :> mode  
    t "-c" args get-argument :> corpus  
    f "-i" args get-argument :> input
    f "-o" args get-argument :> output
    input get-input
    corpus tokenize-corpus
    over [ generate-transitions ] dip
    mode "enc" = [ encode ] [ decode ] if
    output swap write-output ;

: run ( -- ) command-line get (run) ;

MAIN: run 
