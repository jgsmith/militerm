Nonterminals
objects
preposition
word
words
noun_phrase
noun
conjunction
article
quantifier
quantifiers
fraction
count
digit
teen
decimal
numeric
.

Terminals
in
on
against
close
to
under
near
over
behind
before
front
of
beside
containing
holding
with
guarding
blocking
single_word
all
and
the
a
an
any
my
her
hir
his
its
their
number
one
two
three
four
five
six
seven
eight
nine
ten
eleven
twelve
thirteen
fourteen
fifteen
sixteen
seventeen
eighteen
nineteen
twenty
thirty
fourty
fifty
sixty
seventy
eighty
ninety
hundred
thousand
million
slash
.

Rootsymbol objects.

preposition -> in : val('$1').
preposition -> on : val('$1').
preposition -> of : val('$1').
preposition -> against : val('$1').
preposition -> close : val('$1').
preposition -> close to : <<"close to">>.
preposition -> under : val('$1').
preposition -> near : val('$1').
preposition -> over : val('$1').
preposition -> behind : val('$1').
preposition -> before : val('$1').
preposition -> in front of : <<"in front of">>.
preposition -> beside : val('$1').
preposition -> containing : val('$1').
preposition -> holding : val('$1').
preposition -> with : val('$1').
preposition -> guarding : val('$1').
preposition -> blocking : val('$1').

word -> single_word : val('$1').
word -> front : val('$1').
% word -> in.
% word -> on.
% word -> against.
% word -> close.
% word -> to.
% word -> under.
% word -> near.
% word -> over.
% word -> behind.
% word -> before.
% word -> of.
% word -> beside.
% word -> containing.
% word -> holding.
% word -> with.
% word -> guarding.
% word -> blocking.

words -> word : ['$1'].
words -> word words : ['$1' | '$2'].

objects -> noun : ['$1'].
objects -> noun conjunction objects : ['$1' | '$3'].

noun_phrase -> words : [{words, '$1'}].
noun_phrase -> quantifiers words : [{words, '$2'} | '$1'].

noun -> all : [{quantifier, 'all'}].
noun -> noun_phrase : '$1'.
noun -> noun_phrase preposition noun : [{relation, {'$1', '$2', '$3'}}].
noun -> all preposition noun : [{quantifier, 'all'} | '$3'].

conjunction -> and.

article -> the : val('$1').
article -> a : val('$1').
article -> an : val('$1').
article -> any : val('$1').
article -> my : val('$1').
article -> her : val('$1').
article -> hir : val('$1').
article -> his : val('$1').
article -> its : val('$1').
article -> their : val('$1').

quantifier -> article : [{article, '$1'}].
quantifier -> article number : [{article, '$1'}, {quantity, val('$2')}].
quantifier -> count : [{quantity, val('$1')}].
quantifier -> all : [{quantity, 'all'}].
quantifier -> fraction : [{quantity, '$1'}].

quantifiers -> quantifier : ['$1'].
quantifiers -> quantifier of quantifiers : ['$1' | '$3'].

fraction -> number slash number : {fraction, {val('$1'), val('$3')}}.

count -> number : val('$1').
count -> numeric : '$1'.

numeric -> digit : val('$1').
numeric -> teen : val('$1').
numeric -> decimal : val('$1').
numeric -> decimal digit : val('$1') + val('$2').

digit -> one : '$1'.
digit -> two : '$1'.
digit -> three : '$1'.
digit -> four : '$1'.
digit -> five : '$1'.
digit -> six : '$1'.
digit -> seven : '$1'.
digit -> eight : '$1'.
digit -> nine : '$1'.
teen -> ten : '$1'.
teen -> eleven : '$1'.
teen -> twelve : '$1'.
teen -> thirteen : '$1'.
teen -> fourteen : '$1'.
teen -> fifteen : '$1'.
teen -> sixteen : '$1'.
teen -> seventeen : '$1'.
teen -> eighteen : '$1'.
teen -> nineteen : '$1'.
decimal -> twenty : '$1'.
decimal -> thirty : '$1'.
decimal -> fourty : '$1'.
decimal -> fifty : '$1'.
decimal -> sixty : '$1'.
decimal -> seventy : '$1'.
decimal -> eighty : '$1'.
decimal -> ninety : '$1'.

Erlang code.

string(V) -> {string, val(V)}.
val({_, V}) when is_list(V) -> binary:list_to_bin(V);
val({_, V}) when is_number(V) -> V;
val(V) when is_number(V) -> V.


% sentence -> commands
% sentence -> commands string
% sentence -> communication
% sentence -> adverbs communication string adverbs
% sentence -> adverbs communication topic
%
% commands -> adverbs command
% commands -> commands and_then adverbs command
%
% and_then -> 'then'
% and_then -> 'and' 'then'
%
% command -> ttv
% command -> btv
% command -> tv
% command -> mv
% command -> verb_only
%
% communication -> comm
%
% comm_verb_only -> comm_verb adverbs
%
% comm_language -> 'in' language adverbs
%
% comm_target -> indirect_noun_phrase adverbs
%
% comm -> comm_verb_only
% comm -> comm_verb_only comm_language
% comm -> comm_verb_only comm_target
% comm -> comm_verb_only comm_language comm_target
% comm -> comm_verb_only comm_target comm_language
% comm -> comm_language comm_verb_only
% comm -> comm_language comm_verb_only comm_target
% comm -> comm_language comm_target comm_verb_only
% comm -> comm_target comm_verb_only
% comm -> comm_target comm_verb_only comm_language
% comm -> comm_target comm_language comm_verb_only
%
% topic -> topic_intro words
%
% topic_intro -> 'about'
% topic_intro -> 'that'
%
% verb_only -> verb adverbs
% verb_only -> movement_verb_only
%
% mv -> movement_verb_only dmp
%
% tv -> verb_only dnp
% tv -> dnp verb_only
%
% btv -> verb_only indirect_noun_phrase dnp
% btv -> tv indirect_noun_phrase
% btv -> dnp indirect_noun_phrase verb_only
% btv -> indirect_noun_phrase tv
% btv -> movement_verb_only indirect_noun_phrase
% btv -> indirect_noun_phrase movement_verb_only
%
% ttv -> btv instrument_noun_phrase
% ttv -> instrument_noun_phrase btv
% ttv -> verb_only indirect_noun_phrase instrument_noun_phrase dnp
% ttv -> tv instrument_noun_phrase indirect_noun_phrase
% ttv -> dnp instrument_noun_phrase indirect_noun_phrase verb_only
% ttv -> indirect_noun_phrase instrument_noun_phrase tv
%
% adverbs -> adverb
% adverbs -> adverbs 'and' adverb
% adverbs -> adverbs adverb
%
% word -> single_word
% word -> front
% word -> language
%
% words -> word
% words -> words word
%
% instrument_preposition -> 'with'
% instrument_preposition -> 'using'
% instrument_preposition -> 'in'
%
% preposition -> 'in'
% preposition -> 'on'
% preposition -> 'against'
% preposition -> 'close'
% preposition -> 'close' 'to'
% preposition -> 'under'
% preposition -> 'near'
% preposition -> 'over'
% preposition -> 'behind'
% preposition -> 'before'
% preposition -> 'in' 'front' 'of'
% preposition -> 'beside'
% preposition -> 'containing'
% preposition -> 'holding'
% preposition -> 'with'
% preposition -> 'guarding'
% preposition -> 'blocking'
%
% motion_relation -> 'in' 'to'
% motion_relation -> 'on' 'to'
% motion_relation -> 'against'
% motion_relation -> 'close' 'to'
% motion_relation -> 'under'
% motion_relation -> 'near'
% motion_relation -> 'over'
% motion_relation -> 'behind'
% motion_relation -> 'before'
% motion_relation -> 'in' 'front' 'of'
% motion_relation -> 'beside'
% motion_relation -> 'at'
%
% indirect_preposition -> 'from'
% indirect_preposition -> 'to'
% indirect_preposition -> 'at'
% indirect_preposition -> 'through'
% indirect_preposition -> 'from' preposition
% indirect_preposition -> 'to' preposition
%
% dnp -> objects adverbs
%
% dmp -> motion_relation objects adverbs
%
% indirect_noun_phrase -> indirect_preposition objects adverbs
%
% instrument_noun_phrase
