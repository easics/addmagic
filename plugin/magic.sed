/^class/,/^};/!d
/SC_HAS_PROCESS/d
/^signals:/,/^\(public\|protected:\|private:\)/d
/^class/{
N
d
}
/^};$/d
/^$/d
/^public:/d
/^protected:/d
/^private:/d
/= *0;$/d
s/\/\/.*//
/(.*).*;/{
s/^ \+//
b
}
/(.*[^)]/{
h
d
b
}
/[^(].*).*;/{
x
G
s/\n/ /g
s/ \+/ /g
s/^ *//
b
}
H
d
