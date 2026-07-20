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
	opts+=( --allow-dup-id)
	;;
    *東京都小金井市*)
	opts+=( --prohibit-reason-in)
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
    if [ $force = 'no' -a -e py-wkd/${m}_PY-WKD.csv ]; then
	echo SKIP: py-wkd/${m}_PY-WKD.csv exists
    else
	ev time ./vdeathp.rb afterdose --headers ${headers} --weeks 1-99 --ages 80+,all ${opts} --output py-wkd/${m}_PY-WKD.csv ${args}
    fi
    ev xz -f -9 -T0 -k py-wkd/${m}_PY-WKD.csv
    ev mv py-wkd/${m}_PY-WKD.csv.xz kkcor/kkcor/
    (ev cd kkcor/kkcor/ja && ev ln -sf ../${m}_PY-WKD.csv.xz ${l}_PY-WKD.csv.xz)
done
