# chase-bank-PDF-to-QIF.pl: A Perl Script that converts Chase Bank PDF Statement to QIF file
# Copyright(C) 2015 Alex T. Ramos
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use QIF;

# Expect the output file name prefixed with "-o" for safety
if($ARGV[0] =~ /^-o(.+\.qif)/i) { $OUTFILE = $1; shift @ARGV } else { die "Example Usage: $0 -oChase2015.qif *.pdf\n" }

# Force expansion of wildcards as in "2015*.pdf", which is not automatic in Microsoft Windows
if($ARGV[0] =~ /[\*\?]/) { @ARGV = glob($ARGV[0]) }

# start a QIF file
my $out = Finance::QIF->new( file => ">$OUTFILE", debug => 1 );

$out->header( "Type:Bank" );

foreach $file (@ARGV) {
	
	# read the whole PDF file into $data
	local @ARGV = ($file);
	while(<>) { $data .= $_ }

	# extract the year
	($year) = ($data =~  /(\d\d\d\d) Totals Year-to-Date/);
	
	# extract all text marked by "Tj" (PDF Show Text operator)
	$text = join("\n", $data =~ /\(([^\)]*)\)Tj/g);
	#print $text;

	# Extract the transactions. Looking for a simple sequence of Date, Memo, Amount
	while($text =~ m:^(\d\d)/(\d\d)\n(.*)\n(\d+\.\d\d)\n$:mg) {

	  ($month, $day, $memo, $amount) = ($1, $2, $3, $4);  
	  
	  print "($month, $day, $memo, $amount)\n";
	  
	  $record->{header} = "Type:Bank";
	  $record->{date} = "$month/$day/$year";
	  $record->{memo} = $memo;
	  $record->{amount} = $amount;
	  
	  $out->write($record);
	}
}

$out->close();