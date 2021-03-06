#!/bin/bash

LIST=false
while getopts ":g:d:n:l:h" opt; do
  case ${opt} in
    h )
      echo "Usage:"
      echo "    update_database.sh <options>"
      echo "    <options>"
      echo "    -d      GRiD database directory"
      echo "    -g      Bacterial genomes directory"
      echo "    -n      Name for new database"
      echo "    -l      Path to file listing specific genomes"
      echo "            for inclusion in database [default = include all genomes in directory]"
      echo "    -h      Display this message"
      exit 0
      ;;
    d )
          DATABASE_DIR=$OPTARG
          ;;
    g )
          GENOME_DIR=$OPTARG
          ;;
    n )
          NAME=$OPTARG
          ;;
    l )
          LIST=$OPTARG
          ;;
   \? )
     echo "Invalid Option: -$OPTARG" 1>&2
     exit 1
     ;;
     : )
          echo "Invalid Option: -$OPTARG requires an argument" 1>&2
          exit 1
          ;;
     * )
          echo "Unimplemented option: -$OPTARG" >&2
          exit 1
          ;;
  esac
done
###########################################################################
if [ $# -eq 0 ];
then
      echo "Usage:"
      echo "    update_database.sh <options>"
      echo "    <options>"
      echo "    -d      GRiD database directory"
      echo "    -g      Bacterial genomes directory"
      echo "    -n      Name for new database"
      echo "    -l      Path to file listing specific genomes"
      echo "            for inclusion in database [default = include all genomes in directory]"
      echo "    -h      Display this message"
    exit 1
fi
if [ "x" == "x$DATABASE_DIR" ]; then
  echo "-d [option] is required"
  exit 1
fi
if [ "x" == "x$GENOME_DIR" ]; then
  echo "-g [option] is required"
  exit 1
fi
if [ "x" == "x$NAME" ]; then
  echo "-n [option] is required"
  exit 1
fi


###########################################################################
DBR=$(readlink -f $DATABASE_DIR)
GDR=$(readlink -f $GENOME_DIR)


if [ "$LIST" == "false" ]; then

cd $GDR
ls *.fa >> grid_database_genomes.txt
ls *.fna >> grid_database_genomes.txt
ls *.fasta >> grid_database_genomes.txt

cat grid_database_genomes.txt | rev | cut -d'.' -f2- | rev > check_GRiD_genomes.temp.txt
grep -w -f check_GRiD_genomes.temp.txt $DBR/database_misc.txt | cut -f1 > check_GRiD_genomes.txt
if [ -s check_GRiD_genomes.txt ]; then
  rm check_GRiD_genomes.temp.txt
  rm grid_database_genomes.txt
  echo "Some of your genome names already exists in the GRiD database."
  echo "Please rename the genomes in 'check_GRiD_genomes.txt' "
  exit 1
fi
  rm check_GRiD_genomes*
#######
for f in `cat grid_database_genomes.txt` 
do
name=$(ls "$f" | rev | cut -d'.' -f2- | rev)
sed '1d' $f | sed "s/>.*/$(printf '%.0sN' {0..100})/g" | tr -d '\n' | sed "1 i\>$name" > grid_database_$f
done
rm grid_database_genomes.txt

else
LIS=$(readlink -f $LIST)
cd $GDR
cat $LIS | rev | cut -d'.' -f2- | rev > check_GRiD_genomes.temp.txt
grep -w -f check_GRiD_genomes.temp.txt $DBR/database_misc.txt | cut -f1 > check_GRiD_genomes.txt
if [ -s check_GRiD_genomes.txt ]; then
  rm check_GRiD_genomes.temp.txt
  echo "Some of your genome names already exists in the GRiD database."
  echo "Please rename the genomes in 'check_GRiD_genomes.txt' "
  exit 1
fi
  rm check_GRiD_genomes*
####
for f in `cat $LIS`
do
name=$(ls "$f" | rev | cut -d'.' -f2- | rev)
sed '1d' $f | sed "s/>.*/$(printf '%.0sN' {0..100})/g" | tr -d '\n' | sed "1 i\>$name" > grid_database_$f
done
fi
###########################################
#############################################
cat grid_database_* > $NAME
bowtie2-build $NAME $DBR/BOWTIE_$NAME
rm $NAME
##############################################
for f in grid_database_*
do
len=$(awk '/^>/ {if (seqlen){print seqlen}; print ;seqlen=0;next; } { seqlen += length($0)}END{print seqlen}' $f | grep -v ">" | awk '{ total += $1 } END { print total }')
gen=$(grep ">" $f | sed 's/ //g' | sed 's/>//g' | rev | cut -d'.' -f2- | rev )
var1=$(sed '1d' $f | tr -d '\n' | grep -b -o N* | cut -f1 -d':' | awk '{print ($1-1)"p" $0 }' | sed 's/p/p\n/g' | sed '1 i\1' | sed '$s/$/\n'$len'p/' | tr '\r\n' ',')
var2=$(sed '1d' $f | tr -d '\n' | grep -b -o N* | cut -f1 -d':' | awk '{ print $0,"", ($1+99)"d" }' | sed 's/  /,/g' | tr '\r\n' ';')
fragment=$(sed '1d' $f | tr -d '\n' | grep -b -o N* | cut -f1 -d':' | awk '{print ($1-1)"p" $0 }' | sed 's/p/p\n/g' | sed '1 i\1' | sed '$s/$/\n'$len'p/' | tr '\r\n' ',' | sed 's/p,/\n/g' | wc -l)
fpmb=$(echo "scale=3; ($fragment*1000000)/$len" |bc)

echo -e "$gen\t$var1\t$var2\t$len\t$fpmb" >> $DBR/GRiD.temp.misc.txt
done

awk -F'\t' '$2=="" {$2="1,10000000p"};1' OFS='\t' $DBR/GRiD.temp.misc.txt  >> $DBR/database_misc.txt
rm $DBR/GRiD.temp.misc.txt
rm grid_database_*

cd $DBR
ls BOWTIE_$NAME.rev.1.bt2* | rev | cut -d'.' -f4- | rev >> bowtie.txt 

###############################################
