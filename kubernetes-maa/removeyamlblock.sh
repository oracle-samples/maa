export file=$1
export inrootblock=$2
export indeleteblock=$3
export rootblock="$inrootblock:"
export deleteblock="$indeleteblock:"

tmpfile=$(mktemp)
cp $file "$tmpfile" 
awk -v rb="$rootblock" -v db="$deleteblock" '$1 == rb{t=1}
   t==1 && $1 == db{t++; next}
   t==2 && /:[[:blank:]]*$/{t=0}
   t != 2' $tmpfile >$file
rm $tmpfile
