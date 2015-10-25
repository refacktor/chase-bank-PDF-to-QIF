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
	$data = join('', <>);

	# extract all text marked by "Tj" (PDF Show Text operator)	
	$text = join("\n", $data =~ /^\s*\[?\((.*?)\)\]?\s*T[Jj]/mg);

	# extract some statement-level info
	($stmt_month, $stmt_day, $stmt_year) = ($text =~ m[^Statement Date:\n(\d\d)/(\d\d)/(\d\d)$]m);
	($preBal) = ($text =~ /^Previous Balance\n([\-\$\d,\.]+)$/m);
	($newBal) = ($text =~ /^New Balance\n([\-\$\d,\.]+)$/m);
	
	#print $text;
	$stmt_year = 2000 + $stmt_year;
	
	print "$file: Statement dated $stmt_month/$stmt_day/$stmt_year: Start = $preBal, Ending = $newBal\n";
	$preBal =~ s/[\$,]//g;  # remove formatting chars
	$newBal =~ s/[\$,]//g;
	
	if($fileCount++ == 0) { # add an opening balance into the QIF file for more streamlined importing
	  $record->{header} = "Type:Bank";
	  $record->{date} = ($stmt_month==1) ? "12/$stmt_day/" . ($stmt_year-1) : ($stmt_month - 1) . "/$stmt_day/$stmt_year";
	  $record->{memo} = "Opening Balance";
	  $record->{amount} = -$preBal;
	  $out->write($record);	  
	}

	my $total = 0;

	# Extract the transactions. Looking for a simple sequence of Date, Memo, Amount
	while($text =~ m:^(\d\d)/(\d\d)\s*\n(.*)\n(\-?\d*(,\d\d\d)*\.\d\d)$:mg) {

	  ($month, $day, $memo, $amount) = ($1, $2, $3, $4);  
	  $amount =~ s/,//g;

	  # October-December transactions showing up in January-March belong to the previous year.
	  $txn_year = ($stmt_month <= 3 && $month >= 10) ? $stmt_year - 1 : $stmt_year;
	  $date = "$month/$day/$txn_year";
	  
	  $record->{header} = "Type:Bank";
	  $record->{date} = $date;
	  $record->{memo} = $memo;
	  $record->{amount} = -$amount; # for credit card, negative numbers are payments
	  $out->write($record);
	  
	  $total += $amount;
	  
	  print "$date, $memo, $amount\n";	  
	}
	$missing = sprintf("%.2f", $newBal - ($preBal + $total));
	if($missing != 0) {
		die("Transaction total does not match statement: $preBal + $total not equal $newBal\n");
	}
}

$out->close();