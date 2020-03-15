Definitions.

In = in
On = on
Againt = against
Close = close
To = to
Under = under
Near = near
Over = over
Behind = behind
Before = before
Front = front
Of = of
Beside = beside
Containing = containing
Holding = holding
With = with
Guarding = guarding
Blocking = blocking
All = all
And = and
The = the
A = a
An = an
Any = any
My = my
Her = her
Hir = hir
His = his
Its = its
Their = their
Number = \d+
Slash = /
Space = \s+
One = one
Two = two
Three = three
Four = four
Five = five
Six = six
Seven = seven
Eight = eight
Nine = nine
Ten = ten
Eleven = eleven
Twelve = twelve
Thirteen = thirteen
Fourteen = fourteen
Fifteen = fifteen
Sixteen = sixteen
Seventeen = seventeen
Eighteen = eighteen
Nineteen = nineteen
Twenty = twenty
Thirty = thirty
Fourty = fourty
Fifty = fifty
Sixty = sixty
Seventy = seventy
Eighty = eighty
Ninety = ninety
Hundred = hundred
Thousand = thousand
Million = million
SingleWord = [-a-z_]+

Rules.

{In} : {token, {in, TokenChars}}.
{On} : {token, {on, TokenChars}}.
{Againt} : {token, {against, TokenChars}}.
{Close} : {token, {close, TokenChars}}.
{To} : {token, {to, TokenChars}}.
{Under} : {token, {under, TokenChars}}.
{Near} : {token, {near, TokenChars}}.
{Over} : {token, {over, TokenChars}}.
{Behind} : {token, {behind, TokenChars}}.
{Before} : {token, {before, TokenChars}}.
{Front} : {token, {front, TokenChars}}.
{Of} : {token, {'of', TokenChars}}.
{Beside} : {token, {beside, TokenChars}}.
{Containing} : {token, {containing, TokenChars}}.
{Holding} : {token, {holding, TokenChars}}.
{With} : {token, {with, TokenChars}}.
{Guarding} : {token, {guarding, TokenChars}}.
{Blocking} : {token, {blocking, TokenChars}}.
{All} : {token, {all, TokenChars}}.
{And} : {token, {'and', TokenChars}}.
{The} : {token, {the, TokenChars}}.
{A} : {token, {a, TokenChars}}.
{An} : {token, {an, TokenChars}}.
{Any} : {token, {any, TokenChars}}.
{My} : {token, {my, TokenChars}}.
{Her} : {token, {her, TokenChars}}.
{Hir} : {token, {hir, TokenChars}}.
{His} : {token, {his, TokenChars}}.
{Its} : {token, {its, TokenChars}}.
{Their} : {token, {their, TokenChars}}.
{Number} : {token, {number, TokenChars}}.
{One} : {token, {one, 1}}.
{Two} : {token, {two, 2}}.
{Three} : {token, {three, 3}}.
{Four} : {token, {four, 4}}.
{Five} : {token, {five, 5}}.
{Six} : {token, {six, 6}}.
{Seven} : {token, {seven, 7}}.
{Eight} : {token, {eight, 8}}.
{Nine} : {token, {nine, 9}}.
{Ten} : {token, {ten, 10}}.
{Eleven} : {token, {eleven, 11}}.
{Twelve} : {token, {twelve, 12}}.
{Thirteen} : {token, {thirteen, 13}}.
{Fourteen} : {token, {fourteen, 14}}.
{Fifteen} : {token, {fifteen, 15}}.
{Sixteen} : {token, {sixteen, 16}}.
{Seventeen} : {token, {seventeen, 17}}.
{Eighteen} : {token, {eighteen, 18}}.
{Nineteen} : {token, {nineteen, 19}}.
{Twenty} : {token, {twenty, 20}}.
{Thirty} : {token, {thirty, 30}}.
{Fourty} : {token, {fourty, 40}}.
{Fifty} : {token, {fifty, 50}}.
{Sixty} : {token, {sixty, 60}}.
{Seventy} : {token, {seventy, 70}}.
{Eighty} : {token, {eighty, 80}}.
{Ninety} : {token, {ninety, 90}}.
{Hundred} : {token, {hundred, 100}}.
{Thousand} : {token, {thousand, 1000}}.
{Million} : {token, {million, 1000000}}.
{Slash} : {token, {slash, TokenChars}}.
{Space} : {token, {space, TokenChars}}.
{SingleWord} : {token, {single_word, TokenChars}}.

Erlang code.
