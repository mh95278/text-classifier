#!usr/bin/perl
use strict;
use warnings;
use utf8;
use File::Copy qw/move/;
use File::Basename;

{
  my ($word, $bigram, $file);

  my $file1 = "politik.txt";
  my $file2 = "sport.txt";
  my $file3 = "stopwords.txt";
  opendir(CORPORA,'./artikel') || die $!;
  my @files = readdir(CORPORA);
  my $index = 0;
  # ’.’ und ’..’ aus der liste entfernen:
  $index++ until $files[$index] eq '.';
  splice(@files, $index, 1);
  $index = 0;
  $index++ until $files[$index] eq '..';
  splice(@files, $index, 1);
  close CORPORA;

  open(IN, "<", $file1);
  open(IN2, "<", $file2);
  open(STOP, "<", $file3);

  #Korpora, Stopwortliste einlesen:
  undef $/;
  my $politik_korpus = <IN>;
  my $sport_korpus = <IN2>;
  my $stopwords = <STOP>;
  $/ = "\n";

  close IN;
  close IN2;
  close STOP;

  my %frequenz_politik = %{&frequenz($politik_korpus)};
  my %frequenz_sport = %{&frequenz($sport_korpus)};
  my %stop = %{&frequenz($stopwords)};
  
  #Wörter in Hash speichern, die hauptsächlich in Politikartikeln vorkommen:
  my %indicators_politik = %{&find_indicators(\%frequenz_politik,\%frequenz_sport)};
  
  #Wörter in Hash speichern, die hauptsächlich in Sportartikeln vorkommen:
  my %indicators_sport = %{&find_indicators(\%frequenz_sport,\%frequenz_politik)};
  
  my %bigrams_politik = %{&bigrams($politik_korpus,\%stop)};
  my %bigrams_sport = %{&bigrams($sport_korpus,\%stop)};
  
  #Bigramme, die hauptsächlich in Politik vorkommen:
  my %ind_bigrams_politik = %{&find_indicators_bigrams(\%bigrams_politik,\%bigrams_sport)};
  
  #Bigramme, die hauptsächlich in Sport vorkommen:
  my %ind_bigrams_sport = %{&find_indicators_bigrams(\%bigrams_sport,\%bigrams_politik)};

  foreach $file(@files){
     my ($anz_politik_words, $anz_sport_words, $anz_politik_bigram, $anz_sport_bigram, $anz_politik, $anz_sport);
 
     undef $/;
     open(STATISTIK,">>","statistik.txt");
     open(TEST,"<","./artikel/$file");
     my $test = <TEST>;
     $/ = "\n";
     my @test_words;
     my @test_bigrams;

     #Wortliste aus Artikel erstellen:
     while($test =~ /(\p{L}+)/g){
        push (@test_words, $1);
     }
     
     #Bigrammliste aus Artikel erstellen:
     while($test =~ /(\p{L}+)\s+(?=(\p{L}+))/g){
        $bigram = "$1 $2";
        push (@test_bigrams, $bigram);
     }
     
     #Durchsuchen des Artikels nach Politik- bzw. Sportindikatoren (einzelne Wörter):
     ($anz_politik_words,$anz_sport_words) = &vergleichen(\@test_words,\%indicators_politik,\%indicators_sport);
    
     #Durchsuchen des Artikels nach Politik- bzw. Sportindikatoren (diesmal Bigramme):
     ($anz_politik_bigram,$anz_sport_bigram) = &vergleichen(\@test_bigrams,\%ind_bigrams_politik,\%ind_bigrams_sport);
    
     $anz_politik = $anz_politik_words+$anz_politik_bigram;
     $anz_sport = $anz_sport_words+$anz_sport_bigram;
 
     print STATISTIK "$file\n";
     print STATISTIK "Politiktreffer: $anz_politik\n";
     print STATISTIK "Sporttreffer: $anz_sport\n";
    
     if($anz_politik>$anz_sport){
        mkdir "politik";
        undef $/;
        open (OUTFILE, ">./politik/" . basename($file));
        print OUTFILE "$test", basename($file);
        close OUTFILE;
        print STATISTIK "In Politikordner kopiert.\n";
     }
     elsif($anz_sport>$anz_politik){
        mkdir "sport";
        undef $/;
        open (OUTFILE, ">./sport/" . basename($file));
        print OUTFILE "$test", basename($file);
        close OUTFILE;
        print STATISTIK "In Sportordner kopiert.\n";
     }
        print STATISTIK "\n\n";
  }
  print "Ich habe die Texte in die Ordner \"politik\" und \"sport\" eingeordnet. Die Statistik dazu findest du in \"statistik.txt\".\n";
  print "Aber Vorsicht! Wenn du das Programm nochmal ausführst, wird die Statistik um den neuen Durchlauf erweitert.\n";
}

sub frequenz(){
  my $string = $_[0];
  my %hash;
  while($string =~ /(\p{L}+)/g){
	 $hash{$1}++;
  }
  return \%hash;
}

sub find_indicators(){
  my ($referenz1, $referenz2) = @_;
  my %hash1 = %{$referenz1};
  my %hash2 = %{$referenz2};
  my ($word,%indicators);
  foreach $word(keys %hash1){
	 if(!exists($hash2{$word})){
		$indicators{$word}++;
	 }
	 elsif($hash1{$word} >= $hash2{$word}*5){
		$indicators{$word}++;
	 }
  }
  return \%indicators;
}

sub bigrams(){
  my $korpus = $_[0];
  my %stopwords = %{$_[1]};
  my $bigram;
  my %bigrams;
  while($korpus =~ /(\p{L}+)\s+(?=(\p{L}+))/g){
	 $bigram = "$1 $2";
	 if((!exists $stopwords{$1})&&(!exists $stopwords{$2})){
		$bigrams{$bigram}++;
	 }
  }
  return \%bigrams;
}

sub find_indicators_bigrams(){
  my ($referenz1, $referenz2) = @_;
  my %hash1 = %{$referenz1};
  my %hash2 = %{$referenz2};
  my ($word,%indicators);
  foreach $word(keys %hash1){
	 if(!exists($hash2{$word})){
		if($hash1{$word}>=10){
		  $indicators{$word}++;
		}else{
		}
	 }
	 elsif($hash1{$word} >= $hash2{$word}*10){
		$indicators{$word}++;
	 }
  }
  return \%indicators;
}

sub vergleichen(){
  my($ref1,$ref2,$ref3) = @_;
  my @words = @{$ref1};
  my %ind1 = %{$ref2};
  my %ind2 = %{$ref3};
  my $word;
  my $anzahl_ind1 = 0;
  my $anzahl_ind2 = 0;
  foreach $word(@words){
	 if (exists ($ind1{$word})){
		$anzahl_ind1++;
	 }elsif(exists ($ind2{$word})){
		$anzahl_ind2++;
	 }else{
	 }
  }
  return ($anzahl_ind1, $anzahl_ind2);
}
