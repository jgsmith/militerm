Definitions.

CodeOpen = {{
CodeClose = }}
TagOpen = {
EscapedTagOpen = \\{
ClosingTagOpen = {/
ClosingTagClose = /}
TagClose = }
EscapedTagClose = \\}
OpeningSlash = \\
ClosingSlash = /
VariableOpen = \<
VariableClose = \>
EscapedVariableOpen = \\\<
EscapedVariableClose = \\\>
% EscapedVerbOpen = \\\[
% EscapedVerbClose = \\\]
% VerbOpen = \[
% VerbClose = \]
VerbLiteral = verb
ScriptInclusion = {{([^{}]+|\\[{}])*?}}
Word = [^{}<>\n=\s'":\\-]+
Colon = :
Dash = -
Space = \s+
% Quote = ['"]
SQuote = '
DQuote = "
NewLine = (\n|\n\r|\r)
Equal = =
Rules.
{Word} : {token, {word, TokenLine, TokenChars}}.
{VerbLiteral} : {token, {verb_literal, TokenLine, TokenChars}}.
{SQuote} : {token, {squote, TokenLine, TokenChars}}.
{DQuote} : {token, {dquote, TokenLine, TokenChars}}.
{Space} : {token, {space, TokenLine, TokenChars}}.
{Colon} : {token, {colon, TokenLine, TokenChars}}.
{Dash} : {token, {dash, TokenLine, TokenChars}}.
{Equal} : {token, {'=', TokenLine, TokenChars}}.
{NewLine} : {token, {new_line, TokenLine, TokenChars}}.
{TagOpen} : {token, {'{', TokenLine, TokenChars}}.
{EscapedVariableOpen} : {token, {'\\<', TokenLine, TokenChars}}.
{EscapedVariableClose} : {token, {'\\>', TokenLine, TokenChars}}.
% {EscapedVerbOpen} : {token, {'\\[', TokenLine, TokenChars}}.
% {EscapedVerbClose} : {token, {'\\]', TokenLine, TokenChars}}.
{EscapedTagOpen} : {token, {'\\{', TokenLine, TokenChars}}.
{ClosingTagOpen} : {token, {'{/', TokenLine, TokenChars}}.
{ClosingTagClose} : {token, {'/}', TokenLine, TokenChars}}.
{OpeningSlash} : {token, {'\\', TokenLine, TokenChars}}.
{TagClose} : {token, {'}', TokenLine, TokenChars}}.
{EscapedTagClose} : {token, {'\\}', TokenLine, TokenChars}}.
{VariableOpen} : {token, {'<', TokenLine, TokenChars}}.
{VariableClose} : {token, {'>', TokenLine, TokenChars}}.
{CodeOpen} : {token, {'{{', TokenLine, TokenChars}}.
{CodeClose} : {token, {'}}', TokenLine, TokenChars}}.
{ScriptInclusion} : {token, {script, TokenLine, TokenChars}}.
% {VerbOpen} : {token, {'[', TokenLine, TokenChars}}.
% {VerbClose} : {token, {']', TokenLine, TokenChars}}.

Erlang code.
