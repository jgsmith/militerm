Nonterminals
text
markup
tag
tag_name
attributes
attribute
attribute_value
slot
slot_spec
resource
% verb
% verb
.

Terminals
word
% verb_literal
space
squote
dquote
colon
dash
script
new_line
'{'
'{{'
'}}'
'{/'
'/}'
'}'
'<'
'>'
% '['
% ']'
'='
'\\'
'\\<'
'\\>'
'\\{'
'\\}'
% '\\['
% '\\]'
.

Rootsymbol text.

text -> markup text : ['$1' | '$2'].
text -> markup : ['$1'].

markup -> resource : '$1'.
markup -> tag : '$1'.
markup -> slot : '$1'.
% markup -> verb : '$1'.

markup -> word : string('$1').
markup -> space : string('$1').
markup -> squote : string('$1').
markup -> dquote : string('$1').
markup -> colon : string('$1').
markup -> new_line : string('$1').
markup -> dash : string('$1').
markup -> script : parse_script(val('$1')).

markup -> '>' : string('$1').
markup -> '=' : string('$1').
markup -> '\\' : string('$1').
markup -> '\\<' : string('$1').
markup -> '\\>' : string('$1').
markup -> '\\{' : string('$1').
markup -> '\\}' : string('$1').

tag -> '{' tag_name '}' text '{/' tag_name '}' : tag('$2', '$4', '$6').
tag -> '{' tag_name '}' '{/' tag_name '}' : tag('$2', [], '$5').
tag -> '{' tag_name '/}' : tag('$2', [], '$2').
tag -> '{' tag_name space attributes '}' text '{/' tag_name '}' : tag('$2', '$4', '$6', '$8').
tag -> '{' tag_name space attributes '}' '{/' tag_name '}' : tag('$2', '$4', [], '$7').
tag -> '{' tag_name space attributes '/}' : tag('$2', '$4', [], '$2').

tag_name -> word tag_name : [string('$1') | '$2'].
tag_name -> colon tag_name : [string('$1') | '$2'].
tag_name -> dash tag_name : [string('$1') | '$2'].
tag_name -> word : [string('$1')].

attributes -> attribute space attributes : ['$1' | '$3'].
attributes -> attribute : ['$1'].

attribute -> word '=' squote attribute_value squote : attribute('$1', '$4').
attribute -> word '=' dquote attribute_value dquote : attribute('$1', '$4').

attribute_value -> word attribute_value : [string('$1') | '$2'].
attribute_value -> space attribute_value : [string('$1') | '$2'].
attribute_value -> slot attribute_value : ['$1' | '$2'].
attribute_value -> resource attribute_value : ['$1' | '$2'].
attribute_value -> word : [string('$1')].
attribute_value -> space : [string('$1')].
attribute_value -> slot : ['$1'].
attribute_value -> resource : ['$1'].

resource -> '{{' word '}}' : {value, val('$3')}.
resource -> '{{' word colon word '}}' : {resource, val('$3'), val('$5')}.

slot -> '<' slot_spec '>' : {slot, '$2'}.
% verb -> '<' verb_literal colon slot_spec '>' : {verb, '$2'}.

slot_spec -> word : val('$1').
slot_spec -> word colon word : {val('$1'), val('$3')}.

Erlang code.

string(V) -> {string, val(V)}.
val({_, _, V}) -> V.

parse_script(V) -> 'Elixir.Militerm.Parsers.MML':parse_script(binary:list_to_bin(V)).

attribute(Name, Val) -> {val(Name), Val}.
attributes(A) -> {attributes, A}.

tag(StartName, Markup, EndName) ->
  if
  StartName =:= EndName ->
    {tag, [{name, StartName}], Markup};
  true ->
    return_error(1, tag_mismatch_msg(StartName, EndName))
  end.

tag(StartName, Attributes, Markup, EndName) ->
  if
  StartName =:= EndName ->
    {tag, [{name, StartName}, attributes(Attributes)], Markup};
  true ->
    return_error(1, tag_mismatch_msg(StartName, EndName))
  end.

tag_mismatch_msg(StartName, EndName) ->
  lists:concat(['\'', val(StartName), '\' does not match closing tag name \'', val(EndName), '\'']).
