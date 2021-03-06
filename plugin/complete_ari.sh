#! /bin/sh

ari_file=$1

if [ -f /tmp/ari_debug ]; then
  debug=1
else
  debug=0
fi

make_relative()
{
    # Usage: path_from <src_dir> <dst_dir>
    # Desc: calculates a relative path from <src_dir> to <dst_dir>

    local SRC_DIR DST_DIR SRC_LIST DIR REL_PATH DST_LIST
    SRC_DIR=$1
    DST_DIR=$2

    SRC_DIR=`echo $SRC_DIR | sed 's/^\///'`
    DST_DIR=`echo $DST_DIR | sed 's/^\///'`

    SRC_LIST=`echo $SRC_DIR | sed 's/\// /g'`
    for DIR in $SRC_LIST; do
        expr "$DST_DIR" : "$DIR/" > /dev/null || \
        expr "$DST_DIR" : "$DIR\$" > /dev/null || break
        SRC_DIR=`echo $SRC_DIR | sed "s/^\\\\($DIR\\\\/\\\\|$DIR\\\$\\\\)//"`
        DST_DIR=`echo $DST_DIR | sed "s/^\\\\($DIR\\\\/\\\\|$DIR\\\$\\\\)//"`
    done


    if [ "X$SRC_DIR" = X -a "X$DST_DIR" = X ]; then
        REL_PATH=.
    else
        REL_PATH=`echo $SRC_DIR | sed 's/[^/][^/]*/../g'`/$DST_DIR
    fi

    echo $REL_PATH | sed 's:^/::'

    return 0
}

awk_script=$(mktemp)
cat > $awk_script <<EOF
BEGIN {
  dump = 0
  prev_line = ""
}
/^}/ {
  dump = 0
}
{
  if (dump == 1)
    print gensub(";", "", 1, \$3)
}
/^{/ {
  if (match(prev_line, "^hierarchy"))
    {
      dump = 1
    }
}
/^hierarchy.*{/ {
  dump = 1
}
{
  prev_line = \$0
}
EOF

cd $(dirname $ari_file)

if [ $debug == 1 ]; then
  cat $awk_script > ~/tmp/awkscript
  $(awk -f $awk_script $ari_file &> ~/tmp/awkresult)
fi
entities=$(awk -f $awk_script $ari_file | sort -u)

# remove the ones that already have an info section
info_sections=$(grep '^info ' $ari_file | sed -e 's/info //')
for info in $info_sections; do
  entities=$(echo $entities | sed -e "s/\\<$info\\>//")
done

if [ $debug = "1" ]; then
  echo "Entities that have no info section"
  echo $entities
fi

# find each entity
cat > $awk_script <<EOF
/^name = / { library = \$3 }
/^ *search_dir = / { printf("%s:%s\n", library, \$3) }
EOF
if [ ! -e vma.ini ]; then
  if [ ! -z "$VMA_INI" ]; then
    vma_ini=$VMA_INI
  else
    echo "vma.ini not found"
    exit -1
  fi
else
  vma_ini="vma.ini"
fi
search_dirs=$(awk -f $awk_script $vma_ini)

ari_file_dir=$(dirname $ari_file)
cat /dev/null > /tmp/ari_append

if [ $debug = "1" ]; then
  echo $search_dirs
fi

for search_dir in $search_dirs; do
  library=${search_dir%:*}
  search_dir=${search_dir#*:}
  search_dir_work=${search_dir/\$DESIGN_WORK_DIR}
  search_dir_work=${search_dir_work/\$\{DESIGN_WORK_DIR\}}
  relative=0
  if [ "$search_dir" != "$search_dir_work" ]; then
    relative=1
  fi
  if [ $debug = "1" ]; then
    echo $search_dir
  fi
  for entity in $entities; do
    real_search_dir=$(eval echo $search_dir)
    if [ ! -d $real_search_dir ]; then
      echo "Warning : $real_search_dir does not exist"
      continue
    fi
    if [ $debug = "1" ]; then
      echo "Searching location "
    fi
    location=$(find $real_search_dir -iname ${entity}_ent.vhd -o \
                                     -iname ${entity}_ENT.vhd -o \
                                     -iname ${entity}.e.vhd -o \
                                     -iname ${entity}.e.vhdl -o \
                                     -iname ${entity}.vhdl -o \
                                     -iname ${entity}.vhd)
    if [ $debug = "1" ]; then
      echo $location
    fi
    # Skip empty files (generated by vma/sma)
    non_empty=""
    for loc in $location; do
      if [ -s $loc ]; then
        non_empty="$non_empty $loc"
      fi
    done
    location=$non_empty
    # if nothing found, search again with a more liberal pattern
    if [ -z "$location" ]; then
      echo "Tes1t"
      location=$(find -L $real_search_dir -iregex ".*[.]vhdl?" -type f -print0 \
      2>/dev/null | xargs -0 grep -i -l "^[ ]*entity[ ]*${entity}[ ]*is$")
    fi
    if [ $debug = "1" ]; then
      echo $location
    fi

    # Skip empty files (generated by vma/sma)
    non_empty=""
    for loc in $location; do
      if [ -s $loc ]; then
        non_empty="$non_empty $loc"
      fi
    done
    location=$non_empty
    location_words=$(echo $location | wc -w)
    if [[ ${location_words} -eq 1 ]]; then
      if [ $debug = "1" ]; then
        echo $location
      fi
      dir=$(dirname $location)
      abs_dir=$dir
      if [ $relative = 1 ]; then
        location=$(make_relative $ari_file_dir $location)
        dir=$(make_relative $ari_file_dir $dir)
      else
        location=$(echo $location | sed -e "s:^$real_search_dir:$search_dir:")
        dir=$(echo $dir | sed -e "s:^$real_search_dir:$search_dir:")
      fi
      if [ -e $abs_dir/$entity.ari ]; then
        entities=$(echo $entities | sed -e "s/\\<$entity\\>//")
        cat >> /tmp/ari_append <<EOF

info $entity
{
  exec : ariadne $dir/$entity.ari;
  from : $location;
  library : $library;
};
EOF
      else
        entities=$(echo $entities | sed -e "s/\\<$entity\\>//")
        cat >> /tmp/ari_append <<EOF

info $entity
{
  from : $location;
  library : $library;
};
EOF
      fi
    elif [[ $location_words -gt 1 ]]; then
      echo "Multiple files found for $entity"
      for f in $location; do
        echo $f
      done
    fi
  done
done

rm $awk_script
