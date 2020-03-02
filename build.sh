DIR=`dirname $0`

make -C $DIR
cp $DIR/gep/gep $1
