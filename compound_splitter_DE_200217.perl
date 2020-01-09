#!/usr/bin/perl -w

##############################################################
## Compound Splitter for German nouns, verbs and adjectives ##
##                                                          ##
## Marion Weller-Di Marco                                   ##
## wellermn@ims.uni-stuttgart.de                            ##
##                                                          ##
##############################################################

use strict;
use Getopt::Long;

my $split_aggr = 0;
my $show_all = 0;
my $max_num_parts = 4;
my $keeplemma = 0;

GetOptions ("aggressive=s" => \$split_aggr,
            "showall=s" => \$show_all,
            "maxnumparts=s" => \$max_num_parts);

#######################################################################
## Usage:                                                            ##
## perl compound_splitter_DE.perl (options) input.txt > output.txt   ##
## --aggressive=1/0     (optional)                                   ##
## --showall=1/0        (optional)                                   ##
## --maxnumparts=2/3/4  (optional)                                   ##
#######################################################################
## --keeplemma (no lemmatization of head: kaffeesorte *-> kaffe|ort) ##
##   this is a bit experimental though ...                           ##
#######################################################################

### CHANGE YOUR PATH HERE ####################################

my $folder = "ToyData";
my $in_all_freq = "$folder/all_pos_freq.txt";
my $in_all_lem = "$folder/all_pos_lem.txt";

### MAYBE CHANGE THRESHOLDS ##################################

## minimum frequency for a lemma to be considered
my $minFreq = 1; ## was previously set to 5;
                 ## 1 or 2 seems to work slightly better
                 ## this depends on your training data ...

## Minimum word length
my $minWordLen = 2;    

## set to 2: 
## you might get oversplittings such as "gegenpart|ei" (ei = egg, thus a valid splitting option ...)

## depending on your data: maybe remove every word of length 2 from your training data that is not valid
## see here for a list of correct words of length 2:
## https://www.wort-suchen.de/2/m/2014/02/Woerter-mit-2-Buchstaben-fuer-Scrabble.pdf

## set to 3 or higher:
## you will miss analyses such as "hühnerei -> huhn|ei" (chicken|egg)

### READ LEXICON FILES #######################################

my %hash_freq;
my %hash_lem;

open(IN_FREQ, $in_all_freq) or die "cannot open $in_all_freq\n";
while(<IN_FREQ>) {
    chomp;    
    (my $w, my $p, my $f) = split/\t/;
    $hash_freq{$w}{$p} += $f;   
} 
close(IN_FREQ);

open(IN_LEM, $in_all_lem) or die "cannot open $in_all_lem\n";                      
while(<IN_LEM>) {
    chomp;
    (my $w, my $p, my $lem) = split/\t/;
    $hash_lem{$w}{$p} = $lem;
}
close(IN_LEM);

##########################################

my %ignore = (
    "zwische" => 1, ##  this is just wrong
    "ge" => 1,  
    "be" => 1,      
    "ver" => 1,     ## add particles/prefixes if necessary 
);

## words that can look like other words when the fugenelement is removed/added (-> for modifier position)
## not complete; "ei/eis/ein" and "nicht" are probably the most important ones
my %dont_modify = (
    "eis" => "s",      ### following entries
    "laus" => "s",     ### do not remove the listed fugenelement for these words 
    "maus" => "s",
    "mais" => "s",

    "marke" => "e",     ### following entries
    "note" => "e",      ### do not add "e" as fugenelement
    "reise" => "e",     ### -> do not generate "reise|pflanze" :-)
    "rinde" => "e",
    "sekte" => "e",
    "akte" => "e",
    "decke" => "e",
    "nichte" => "e",    ### negation "nicht" -> "nichte" (niece)
    "schranke" => "e",
    "watte" => "e",
    "weiche" => "e",
    "ente" => "e",      ### prefix "ent" -> "ente" (duck)
    "eine" => "e"
);    

########### START SPLITTING ############

my %poss;
my %modified;  ## keeps track whether a splitting was obtained based on modifications 
               ## (removing/adding a fugenelement) -> to be disfavoured in case of equal score

while(<>) {
    chomp;
    (my $word_to_split, my $cat_pos, my $rest) = split(/\t/);
   
    $word_to_split = &lowercase($word_to_split);
    my $word_to_split_copy = $word_to_split;
    $word_to_split =~ s/-//g;
    $word_to_split =~ s/_//g;

    $word_to_split = $word_to_split."_".$cat_pos;

    #### split word ###############################################
 
    my %poss = %{&split_into_two_parts($word_to_split."RIGHTMOST")};

    
    #### for each found split - split parts #######################
    #### max. 4 splits total ######################################
    
    my %tmpHash = %poss;
    foreach my $split (keys %tmpHash) {
	(my $comp1, my $comp2) = split(/ /, $split);

	#print"\n\nC1:$comp1\nC2: $comp2\n\n";
	
	(my $comp2_w, my $comp2_c) = split(/_/, $comp2);
	my $comp2_voll = $tmpHash{$split};     

	my %hash_comp1 = %{&split_into_two_parts($comp1)};
	my %hash_comp2 = %{&split_into_two_parts($comp2_voll."RIGHTMOST")};
	
	foreach my $m1 (keys %hash_comp1) {
	    $poss{"$m1 $comp2"} = $tmpHash{$split}; 
	}

	foreach my $m2 (keys %hash_comp2) {
	    $poss{"$comp1 $m2"} = $hash_comp2{$m2}; 
	}
	
	foreach my $m1 (keys %hash_comp1) {
	    foreach my $m2 (keys %hash_comp2) {		
		$poss{"$m1 $m2"} = $hash_comp2{$m2};
	    }
	}
    }

    #### add non-split word #######################################

    my @all_that_is_in_hash = keys(%poss);
    my $lenHash = @all_that_is_in_hash;

    if ($split_aggr == 0) {

	if (exists $hash_lem{$word_to_split_copy}{$cat_pos}) { 
	    my $tmptmp = $hash_lem{$word_to_split_copy}{$cat_pos};

	    if (exists $hash_freq{$tmptmp}{$cat_pos}) {
		$poss{$tmptmp."_".$cat_pos} = $word_to_split_copy."_$cat_pos";
	    }
	    else {
		#warn "WARN (1) $word_to_split_copy $tmptmp  $cat_pos\n";
		$poss{$word_to_split} = $word_to_split_copy."_$cat_pos";   # added
		$hash_freq{$word_to_split_copy}{$cat_pos} = 0;             # added
	    }       
	}
	else {	
	    if (exists $hash_freq{$word_to_split_copy}{$cat_pos}) {
		$poss{$word_to_split} = $word_to_split_copy."_$cat_pos";
	    }
	    else {
		#warn "WARN (2) $word_to_split_copy $word_to_split  $cat_pos\n";
		$poss{$word_to_split} = $word_to_split_copy."_$cat_pos";
		$hash_freq{$word_to_split_copy}{$cat_pos} = 0;
	    }	
	}
    }

    #### compute scores ###########################################
    my %poss_scores;

    foreach my $entry (keys %poss) {
	my $tmp_score = 1;
	my @parts = split(/ /, $entry);

	## number of parts
	my $n = @parts;

	foreach my $part (@parts) {
	  
	    (my $word_p, my $cat_p) = split(/_/, $part);

	    my $tmp = 0;
	    if (exists $hash_freq{$word_p}{$cat_p}) {
		$tmp = $hash_freq{$word_p}{$cat_p};
	    }

	    $tmp_score = $tmp_score*$tmp;
	}
	
	$tmp_score = $tmp_score**(1/$n);
	$poss_scores{$entry} = $tmp_score;
    }

    ### find split with best score ################################

    my @tmp_keys = keys (%poss_scores);
    my @all_keys_tmp = sort{$poss_scores{$b}<=>$poss_scores{$a}}(@tmp_keys);


    ### Check Split length ########################################

    my @all_keys = ();

    foreach my $p (@all_keys_tmp) {
	my @tmp_split = split(/ /, $p);
	my $split_len = @tmp_split;

	unless ($split_len > $max_num_parts) {
	    push(@all_keys, $p);
	}
    }    
    ### Heuristic for equal scores ################################

    ## if two analyses have equal scores: take the one that is less modfied

    my $len_neu = @all_keys;
    for (my $i=0; $i<$len_neu; $i++) {

	my $p = $all_keys[$i];
	my $p_plus1 = "XYZ";
	
	if ($i+1 < $len_neu) {
	    $p_plus1 =  $all_keys[$i+1];

	    if ($p !~ /X/ && $p_plus1 !~ /X/) {
		if ($poss_scores{$p} == $poss_scores{$p_plus1}) {
		    ## put non-modified before modified

		    my @analysis_curr = split(/ /, $p);
		    my @analysis_next = split(/ /, $p_plus1);

		    my $modified_curr = 0;
		    foreach my $part (@analysis_curr) {
			if (exists $modified{$part}) {
			    $modified_curr += 1;
			}
		    }
		    
		    my $modified_next = 0;
		    foreach my $part (@analysis_next) {
			if (exists $modified{$part}) {
			    $modified_next += 1;
			}
		    }

		    ## switch current and next, because the next is probably better
		    if ($modified_next < $modified_curr) {
			$all_keys[$i] = $p_plus1;
			$all_keys[$i+1] = $p;			
		    }

		    #if ($modified_curr == $modified_next && $i==0 && $poss_scores{$p}>0) {
		    #	print "EQUAL\t$p ($modified_curr) | $p_plus1 ($modified_next)  ";
		    #	print $poss_scores{$p}."\n";
		    #}
		}
	    }
	}	    	
    }

    ### Ausgabe ###################################################    
    
    if ($show_all == 1) {
	my $printed = 0;
	foreach my $p (@all_keys) {
	    unless ($p =~ /_X/) {
		#print "$word_to_split_copy\t";
	    
		##inflected head
		my @tmparray = split(/ /, $p);
		my $infl_head = $poss{$p};
		$tmparray[-1] = $infl_head;
		
		my $infl_split = join(" ", @tmparray);
		unless ($poss_scores{$p} == 0) {
		    print "$word_to_split_copy\t";
		    print"$p\t$infl_split\t".$poss_scores{$p}."\n";
		    $printed = 1;
		}
	    }
	}

	if ($printed == 0) {
	    print "$word_to_split_copy\t";
            print "$word_to_split_copy"."_"."$cat_pos\t";
	    print "$word_to_split_copy"."_"."$cat_pos\t";
	    print "0\n";
	}
	
	print"\n";
    }
    else {
	my $index = @all_keys;
	my $z = 0;
	my $printed = 0;

	while($z < $index) {
	    if (defined $all_keys[$z]) {
		#print "<$word_to_split_copy>\t";
		my $p = $all_keys[$z];
		
		##inflected head
		my @tmparray = split(/ /, $p);
		my $infl_head = $poss{$p};
		$tmparray[-1] = $infl_head;
		
		my $infl_split = join(" ", @tmparray);

		unless ($p =~ /_X/) {
		    if ($poss_scores{$p} > 0) {
			print "$word_to_split_copy\t";  
			print"$p\t$infl_split\n";
			$printed = 1;
			last;
		    }
		}		    
	    }
	    $z ++;
	}
	
	if ($printed == 0) {
	    print "$word_to_split_copy\t";
            print "$word_to_split_copy"."_"."$cat_pos\t";
	    print "$word_to_split_copy"."_"."$cat_pos\n";
	}
    }
    
    #### delete hash ##############################################

    for (keys %poss) { delete $poss{$_} };
    for (keys %modified) { delete $modified{$_} };
}

#------------------------------------------------------------------------------------

sub split_into_two_parts ($) {
    my $arg = shift;
    my %hash;
    my @sub_array;

    my $rightmost = 0;
    if ($arg =~ /RIGHTMOST$/) {
	$rightmost = 1;
	$arg =~ s/RIGHTMOST$//;
    }
    
    (my $word, my $cat) = split(/_/, $arg);

    my @word = split(//, $word);
    my $len = @word;

    my $copy_cat = $cat;

    ### min-word_len = set above

    for (my $i=$minWordLen; $i<= $len-$minWordLen; $i++) {
	my @tmp = @word;

	my @p2 = splice(@tmp, $i);  ## ab i bis ende 
	my @p1 = @tmp;

	my $str1 = join("", @p1);
	my $str2 = join("", @p2);
	$cat = $copy_cat;

	### head_nomen    
	my $head_found = 0;	
	my $head_lemma = "";

	my $found_non_head = 0;

	#print"$str1   $str2   $cat\n";

	## find category for X
	if ($cat =~ /X/) {
	    if (exists $hash_lem{$str2}{"V"} && &check_conditions_head($str2, "V", $str2, $rightmost) == 1) {
		$cat = "V";
	    }		
	    if (exists $hash_lem{$str2}{"ADJ"} && &check_conditions_head($str2, "ADJ", $str2, $rightmost) == 1) {
		$cat = "ADJ";
            } 
	    if (exists $hash_lem{$str2}{"NN"} && &check_conditions_head($str2, "NN", $str2, $rightmost) == 1) {
		$cat = "NN";
	    }
	    ## ADDED
	    if (exists $hash_lem{$str2}{"ADV"} && &check_conditions_head($str2, "ADV", $str2, $rightmost) == 1) {
		$cat = "ADV";
	    }
	    if (exists $hash_lem{$str2}{"PART"} && &check_conditions_head($str2, "PART", $str2, $rightmost) == 1) { 
		$cat = "PART";
	    }
	    if (exists $hash_lem{$str2}{"NE"} && &check_conditions_head($str2, "NE", $str2, $rightmost) == 1) {
		$cat = "NE";		
	    }
	    if (exists $hash_lem{$str2}{"OTHER"} && &check_conditions_head($str2, "OTHER", $str2, $rightmost) == 1) {
		$cat = "OTHER";		
	    }
	}

	## left component of category X contains fugenelement / is not complete
        if ($cat =~ /X/) {
            my $tmp_str2 = $str2."en";
            if (exists $hash_lem{$tmp_str2}{"V"} && &check_conditions_head($tmp_str2, "V", $tmp_str2, $rightmost) == 1) {
                $cat = "V";
                $str2 = $tmp_str2;
            }
        }   

        if ($cat =~ /X/ && $str2 =~ /(s|r|n)$/) {
            my $fuge = $1;
            my $tmp_str2 = $str2;
            $tmp_str2 =~ s/$fuge$//;
            if (exists $hash_lem{$tmp_str2}{"NN"} && &check_conditions_head($tmp_str2, "NN", $tmp_str2, $rightmost) == 1) {
                $cat = "NN";
                $str2 = $tmp_str2;
            }
        }       

	
	## CHECK HEAD LEMMA
	if ($cat =~ /^NN$/) {
	    if (exists $hash_lem{$str2}{"NN"} && not exists $ignore{$str2} && $str2 =~ /^...+/) {
		my $tmpheadlem = $hash_lem{$str2}{"NN"};
		if (&check_conditions_head($tmpheadlem, "NN", $str2, $rightmost) == 1) {
		    $head_lemma = $hash_lem{$str2}{"NN"}."_NN";
		    $head_found = 1;
		}
	    }	    
	}
	elsif ($cat =~ /^(ADJ|ADV|PART|NE|OTHER)$/) {
	    my $key_cat = $cat;
	    if (exists $hash_lem{$str2}{$key_cat} && not exists $ignore{$str2} && $str2 =~ /^...+/) {
		my $tmpheadlem = $hash_lem{$str2}{$key_cat}; 
		if (&check_conditions_head($tmpheadlem, $key_cat, $str2, $rightmost) == 1) {
		    $head_lemma = $hash_lem{$str2}{$key_cat}."_".$key_cat;  
		    $head_found = 1;
		}
	    }
	}
	elsif ($cat =~ /^V/) {
	    if (exists $hash_lem{$str2}{"V"} && not exists $ignore{$str2} && $str2 =~ /^...+/) {
		my $tmpheadlem = $hash_lem{$str2}{"V"}; 
		if (&check_conditions_head($str2, "V", $str2, $rightmost) == 1) {
		    $head_lemma = $hash_lem{$str2}{"V"}."_V";  
		    $head_found = 1;
		}
	    }
	}

	
	### ERSTE KOMPONENTE
	if ($head_found == 1) {	    
	    #print"-> $head_lemma  ($str1)\n";
	    if (&check_conditions($str1, "NN") == 1) {
		push(@sub_array, @{&insert_into_hash("$str1\_NN $head_lemma", "$str2\_$cat")});
		$found_non_head = 1;		
	    }
	    if (&check_conditions($str1, "ADJ") == 1) {
		push(@sub_array, @{&insert_into_hash("$str1\_ADJ $head_lemma", "$str2\_$cat")});
		$found_non_head = 1;
            } 
	     if (&check_conditions($str1, "V") == 1) {
		 push(@sub_array, @{&insert_into_hash("$str1\_V $head_lemma", "$str2\_$cat")});
		 $found_non_head = 1;
            } 
	    #### ADDED
	    if (&check_conditions($str1, "ADV") == 1) {
                push(@sub_array, @{&insert_into_hash("$str1\_ADV $head_lemma", "$str2\_$cat")});
                $found_non_head = 1;
            }
	    if (&check_conditions($str1, "PART") == 1) {
		push(@sub_array, @{&insert_into_hash("$str1\_PART $head_lemma", "$str2\_$cat")});
		$found_non_head = 1;
	    }
	    if (&check_conditions($str1, "NE") == 1) {
		push(@sub_array, @{&insert_into_hash("$str1\_NE $head_lemma", "$str2\_$cat")});
		$found_non_head = 1;
	    }
	    if (&check_conditions($str1, "OTHER") == 1) {
		push(@sub_array, @{&insert_into_hash("$str1\_OTHER $head_lemma", "$str2\_$cat")});
		$found_non_head = 1;
	    }
	    
	    
	    ## WEITERSUCHEN


	    ## NOUN MODIFIER
	    
	    ## s: abbildung*s*fehler    <- ONLY ONE TO BE USED
	    ## REMOVED: n kamille*n*bad (Plural)
	    ## REMOVED: er  fischerboot -> *fisch boot ("kindergarten" is covered with plural-form -> lemma)
	    ## REMOVED: en  buchenlaub -> *buch laub ("tatendrang" is covered with plural-form -> lemma)
	    ## REMOVED: es: kindeswohl (genitiv)
	    ## REMOVED: e  maus*e*falle (this seems to harm more than it helps (wattebausch,solebad, zementestrich), even though it is justified in rare cases) 
	    
	    ## rennauto -> ren auto, eissturm -> eis turm
	    ## How to fix "felsnadel" -> "fels adel" ???
	    	    
	    my @fugenelemente = ("s");    
	    foreach my $element (@fugenelemente) {

		## EXTRA CONDITION
		my $dont = 0;
		if (exists $dont_modify{$str1} && $dont_modify{$str1} eq $element) {   ## eis /-> ei in eisbecher
		    $dont = 1;
		}
		if ($element =~ /^(s|n)$/ && $str1 =~ /$element$element$/) {           ## "double-fugenelement"
		    $dont = 1;
		}
		if ($element =~ /^n$/ && $str1 !~ /e$element$/) {                      ## "double-fugenelement"
		    $dont = 1;
		}
		
		
		if ($str1 =~ /$element$/ && $dont == 0) {
		    my $tmp = $str1;
		    $tmp =~ s/$element$//;
		    if (&check_conditions($tmp, "NN") == 1) {
			push(@sub_array, @{&insert_into_hash("$tmp\_NN $head_lemma", "$str2\_$cat")});
			$found_non_head = 1;
		    }

		    ## Maybe add: martinskirche ABER: linksverkehr -> link_NE verkehr
#		    if (&check_conditions($tmp, "NE") == 1) {
#			push(@sub_array, @{&insert_into_hash("$tmp\_NE $head_lemma", "$str2\_$cat")});
#			$found_non_head = 1;
#		    }
#		    if (&check_conditions($tmp, "OTHER") == 1) {
#			push(@sub_array, @{&insert_into_hash("$tmp\_OTHER $head_lemma", "$str2\_$cat")});
#			$found_non_head = 1;
#		    }
		}
	    }	 
	    
	    ## Kirchturm -> Kirche Turm	    
	    my @fugenelemente_add = ("e");
            foreach my $element (@fugenelemente_add) {
		my $tmp = $str1.$element;
		unless (exists $dont_modify{$tmp} && $dont_modify{$tmp} eq $element) { ## NEU		    
		    if (&check_conditions($tmp, "NN") == 1) {
			push(@sub_array, @{&insert_into_hash("$tmp\_NN $head_lemma", "$str2\_$cat")});
			$found_non_head = 1;
			$modified{"$tmp\_NN"} = 1;
		    }
		}

		## Bindegewebsschwäche -> bindegeweb -> bindegewebe
		## geschichtsbuch, gebirgsbach, ...
		## but not nassbaggerung -> *nase baggerung
		if ($str1 =~ /[^s]s$/) {
		    my $tmp_b = $str1;
		    $tmp_b =~ s/s$//;
		    $tmp_b = $tmp_b.$element;
		    unless (exists $dont_modify{$tmp_b} && $dont_modify{$tmp_b} eq $element) { ## NEU  
			if (&check_conditions($tmp_b, "NN") == 1) {
			    push(@sub_array, @{&insert_into_hash("$tmp_b\_NN $head_lemma", "$str2\_$cat")});
			    $found_non_head = 1;
			    #$modified{"$tmp_b\_NN"} = 1;
			}
		    }
		}

		if ($str1 =~ /[^s]s$/) {
		    my $tmp_b = $str1;
		    $tmp_b =~ s/es$//;
		    $tmp_b = $tmp_b.$element;
		    unless (exists $dont_modify{$tmp_b} && $dont_modify{$tmp_b} eq $element) { ## NEU  
			if (&check_conditions($tmp_b, "NN") == 1) {
			    push(@sub_array, @{&insert_into_hash("$tmp_b\_NN $head_lemma", "$str2\_$cat")});
			    $found_non_head = 1;
			    #$modified{"$tmp_b\_NN"} = 1;
			}
		    }
		}
            }	    

	    ## Umlautung
	    if (exists $hash_lem{$str1}{"NN"}) {
		my $tmp = $hash_lem{$str1}{"NN"};

		if (&check_conditions($tmp, "NN") == 1) {
		    push(@sub_array, @{&insert_into_hash("$tmp\_NN $head_lemma", "$str2\_$cat")});
		    $found_non_head = 1;
		    #$modified{"$tmp\_NN"} = 1;
		}
	    }
	    
	    ## VERB MODIFIER
	    
	    my @fugenelemente_verb = ("n", "en");
            foreach my $element (@fugenelemente_verb) {
                my $tmp = $str1.$element;
		unless (exists $dont_modify{$tmp} && $dont_modify{$tmp} eq $element) { ## NEU
		    if (&check_conditions($tmp, "V") == 1) {
			push(@sub_array, @{&insert_into_hash("$tmp\_V $head_lemma", "$str2\_$cat")});
			$found_non_head = 1;
			$modified{"$tmp\_V"} = 1;
		    }
		}
            }   

	    # rechenmaschine -> rechnen maschine
	    # atemgerät -> atmen gerät
	    my $tmp = $str1;
	    if ($tmp =~ /[^n]en$/) {
		$tmp =~ s/en$/nen/;
	    }
	    elsif ($tmp =~ /[^m]em$/) {
		$tmp =~ s/em$/men/;
	    }
	    
	    unless (exists $dont_modify{$tmp} ) { ## NEU
		if (&check_conditions($tmp, "V") == 1) {
		    push(@sub_array, @{&insert_into_hash("$tmp\_V $head_lemma", "$str2\_$cat")});
		    $found_non_head = 1;
		    $modified{"$tmp\_V"} = 1;
		}
	    }

	    ## ADJ MODIFIER
	    ## nothing to do here
	    	    
	    ##########################################################################################
	    
	    if ($found_non_head == 0) {
		push(@sub_array, @{&insert_into_hash("$str1\_X $head_lemma", "$str2\_$cat")})     
	    }	
	}
    }

    foreach my $e (@sub_array) {
	(my $key, my $value) = split(/ \|\|\| /, $e);
	$hash{$key} = $value;
    }

    return \%hash;
}

#################################################################

sub lowercase ($) {
    my $arg = shift;

    $arg = lc($arg);
    $arg =~ s/Ü/ü/g;
    $arg =~ s/Ä/ä/g;
    $arg =~ s/Ö/ö/g;

    return $arg;
}

#################################################################

sub insert_into_hash ($) {
    my $key = $_[0];
    my $value = $_[1];
    my %tmp_hash;
    my @return_array;

#    print"K:$key\tV:$value\n";

    my @key_parts = split(/ /, $key);
    my $key_parts_len = @key_parts;

    my @tmpArray = ("");
    
    foreach my $part (@key_parts) {

	if ($part =~ /\|/) {
	    my @tmptmp;

	    my $tmpcat = "";
	    $part =~ /_([A-Z]+)$/ or warn "bad form ...\n";
	    $tmpcat = $1;
	    $part =~ s/_[A-Z]+$//;

	    my @ambig = split(/\|/, $part);
	    
	    foreach my $amb (@ambig) {
		foreach my $e (@tmpArray) {
		    push(@tmptmp, $e." ".$amb."_".$tmpcat);
		}
	    }
	    @tmpArray = @tmptmp;
	}
	else {
	    my $tmp_len = @tmpArray;
	    for (my $i=0; $i<$tmp_len; $i++) {
		$tmpArray[$i] = $tmpArray[$i]." ".$part;	    
	    }
	}
    }

    foreach my $e (@tmpArray) {
	$e =~ s/^ //;
	push(@return_array, "$e ||| $value");
    }  

    return \@return_array;
}

#################################################################

sub check_conditions ($) {
    my $tmp_word = $_[0];
    my $tmp_cat = $_[1];    

    my $erg = 1;
    unless (exists $hash_freq{$tmp_word}{$tmp_cat} || exists $hash_lem{$tmp_word}{$tmp_cat}) {
	$erg = 0;
    }    
    if (exists $ignore{$tmp_word}) {
	$erg = 0;
    }
    if ($tmp_cat =~ /^(ADJ|ADV|PART|NE|OTHER)$/ & ($tmp_word =~ /^.$/ || $tmp_word =~ /^..$/ )) {
	$erg = 0;
    }
    if ($tmp_cat eq "V" & ($tmp_word =~ /^.$/ || $tmp_word =~ /^..$/ || $tmp_word =~ /^...$/ || $tmp_word =~ /^....$/)) {
	$erg = 0;
    }
    if ($tmp_cat eq "NN" & $tmp_word =~ /^.$/) {
	$erg = 0;
    }
    if (exists $hash_freq{$tmp_word}{$tmp_cat} && $hash_freq{$tmp_word}{$tmp_cat} < $minFreq) {
	$erg = 0;
    }
    
    return $erg;
}


sub check_conditions_head ($) {
    my $tmp_word = $_[0];
    my $tmp_cat = $_[1];
    my $string2 = $_[2];
    my $rightmost = $_[3];
    
    my $erg = 1;                                                                                              

    unless (exists $hash_freq{$tmp_word}{$tmp_cat} || exists $hash_lem{$tmp_word}{$tmp_cat}) {
        $erg = 0;
    }
    if (exists $ignore{$tmp_word}) {
        $erg = 0;
    }
    if ($tmp_cat =~ /^(ADJ|ADV|PART|NE|OTHER)$/ & ($tmp_word =~ /^.$/ || $tmp_word =~ /^..$/ )) {
        $erg = 0;
    }
    if ($tmp_cat eq "V" & ($tmp_word =~ /^.$/ || $tmp_word =~ /^..$/ || $tmp_word =~ /^...$/ || $tmp_word =~ /^....$/)) {
       $erg = 0;
    }
    if ($tmp_cat eq "NN" & $tmp_word =~ /^.$/) {
        $erg = 0;
    }
    if (exists $hash_freq{$tmp_word}{$tmp_cat} && $hash_freq{$tmp_word}{$tmp_cat} < $minFreq) {
        $erg = 0;
    }

    if ($keeplemma == 1 && $rightmost == 1) {

	## TreeTagger-Problem:
	if ($tmp_word =~ /\|/) {
	    (my $lem1, my $lem2) = split(/\|/, $tmp_word);
	    if ($string2 eq $lem1) {
		$tmp_word = $lem1;
	    }
	    elsif ($string2 eq $lem2) {
		$tmp_word = $lem2;
	    }
	}
	
	unless ($string2 eq $tmp_word) {
	    #print "HIER: $string2   $tmp_word\n";
	    $erg = 0;
	}
    }
    
    return $erg;
}                      
