#!/bin/zsh

ev () {
    echo $*
    eval $*
}

force=no
case $1 in
-f|--force)
	force=yes
	shift 1
	;;
esac

for j in $*
do
    k=`basename $j`
    l=${k%%_80+.csv}
    l=${l%%_all.csv}
    m=$(printf '%s\n' "$l" | sed 's/_[^-][^-]*-/_/')
    echo $i $j
    opts=''
    case $k in
    *愛知県豊川市*|*神奈川県相模原市*)
	opts+=( --allow-dup-id yes)
	;;
    *東京都小金井市*)
	opts+=( --prohibit-reason-in yes)
	;;
    *大阪市*)
	continue
	;;
    esac
    args=${j}
    if [ -e ${j%%.csv}-death.csv ]; then
	args=(${j} ${j%%.csv}-death.csv)
    fi
    headers=src/${l}_header.csv
    if [ -e src/${l}_header-death.csv ]; then
	headers+=,src/${l}_header-death.csv
    fi
    if [ $force = 'no' -a -e data/${m}_PY.csv ]; then
	echo SKIP: data/${m}_PY.csv exists
    else
	ev time ./vdeathp.rb --header ${headers} --steps 1,3,6,all --ages 00-09,10-19,20-29,30-39,40-49,50-59,60-69,70-79,80-89,90-99,100+,80+,all ${opts} ${args} --pyear data/${m}_PY.csv
    fi
    ev xz -f -9 -T0 -k data/${m}_PY.csv
    ev mv data/${m}_PY.csv.xz kkcor/kkcor/
    (ev cd kkcor/kkcor/ja && ev ln -sf ../${m}_PY.csv.xz ${l}_PY.csv.xz)
done
