# Simple Compound Splitting for German

The splitter is started as follows:
perl compound_splitter_DE.perl input_file.txt > output_file.txt

The input-file should look like this:
compound <tab> POS-tag (ADJ, NN, V)

Abfallkatalog   NN
Abfallmenge     NN
Abfallprodukte  NN

(Either true-cased or lower-cased: the splitter will lowercase everything)

You need two word lists (frequency information and wordform-lemma mapping) as training data;
see below for more details.

You can also use use optional output options, see below.


*** OUTPUT ***

The output looks like this:

compound <tab> split compound (all lemmatized) <tab> split compound (inflected head)

breitflügelfledermäuse	breit_ADJ flügel_NN fledermaus_NN	breit_ADJ flügel_NN fledermäuse_NN
breitflügelfledermaus	breit_ADJ flügel_NN fledermaus_NN	breit_ADJ flügel_NN fledermaus_NN

The first word (breitflügelfledermäuse) is the plural form; the splitter outputs a lemmatized analysis
(breit_ADJ flügel_NN fledermaus_NN), as well as an analysis that keeps the inflected form of the head
noun (breit_ADJ flügel_NN fledermäuse_NN); the modifiers are represented in lemmatized format.
This can be useful, e.g. for applications in SMT, if you want to keep information such as number.


*** OPTIONS ***

You can select different output options:

--showall=0/1
Show all possible splits (1) or show only the best split (0: default)

--splitbest=0/1
It is possible that the 'best' analysis is the unsplit compound, e.g. "Freitag" (Friday).
Set to 1 in order to output the best split, including the non-split word.
Set to 0 (default) in order to force the splitter to output a split form as 'best split'.
(If no splitting analysis could be found, the unsplit word is returned)

--maxnumparts=2/3/4
Restricts the number of components: if set to 2, only analyses with 2 components will be shown.


*** METHOD ***
Each compound is split in up to 4 components of the categories noun, verb or adjective,
particle/preposition, adverb and proper noun.
The category of the compound (head word), which is part of the input, cannot be changed.
Based on the frequencies of the components, a score (geometric mean) is computed in
order to rate the different splitting analyses and to identify the best analysis.
(-> see Koehn/Knight 2003: "Empirical Methods for Compound Splitting").


*** DATA ***

The splitter loads two lists: "all_pos_freq.txt" and "all_pos_lem.txt"
You need to set the correct path in line 34.


1) all_pos_freq.txt: frequency list

schwankung      NN      336
mühle   NN      454
mobil   ADJ     749
kreisen	V	123

This list contains frequency information for lemmas.
The format is: lemma <tab> POS-tag <tab> frequency.

All words occurring in this list are considered as potential components in the splitting analyses.
It helps to keep this list as clean as possible to avoid missplittings based on non-valid,
but observed words.
In particular, short strings that are not a real words or morphologically meaningful entities
can occur frequently due to typos or incorrect hyphenation and should be removed from this list.


2) all_pos_lem.txt: list of word forms and their respective lemma 

schwankung      NN      schwankung
schwankungen    NN      schwankung
mobiles		ADJ	mobil
mobiler		ADJ	mobil
fledermäuse     NN      fledermaus
anzeigen        V       anzeigen
bücher  	NN      buch
tüten		NN	tüte

This list maps word forms to their lemma.
The format is: word <tab> POS-tag <tab> lemma.

List (2) is needed to find the lemma of the head noun of the compound 
(the rightmost component of a compound) if the compound happens to be inflected.

Also, it is used to model phenomena like "Umlautung" where the modifier contains an umlaut
('ü' in 'bücher'), whereas the lemma does not contain an umlaut ('u' in 'buch').
In contrast, the word "tüte" keeps the umlaut in the lemma.

bücherregal -> buch regal (book shelf)
tütensuppe -> tüte suppe (lit. bag soup: packet soup)


Both lists should be as large and clean as possible.


*** EXTRA ***

1) %ignore: stop words
you can add words that should not be be part of the splitting analysis.


2) %dont_modify: words for which certain operations are forbidden
you can add words that look like other (non-related) words when a fugenelement is removed/added
in the modifier position.

(1) Removal of "s" or "n":
    eis (ice) -> remove "s" -> ei (egg)
    hain (grove) -> remove "n" -> hai (shark)
(2) Adding "e":
    reis (rice) -> add "e" -> reise (voyage)
    nicht (not) -> add "e" -> nichte (niece)

This list is not complete; some of the entries occur rather frequently, e.g. "nicht" (negation prefix).

