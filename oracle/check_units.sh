# compare units in ./psp/install_psp.sql and units in directory ./psp

cat psp/install_psp_obj.sql | grep @@ | cut -c 3- | tr -d "\r" | sort > ./unit_list.txt
# pbpaste > ./unit_list.txt
git add ./unit_list.txt

ls  psp | grep -v "install_psp_obj.sql" | sort > ./unit_list.txt
# ls  psp | grep -v "install_psp_obj.sql"| cut -d . -f 1 | sort > ./unit_list.txt
git diff -- ./unit_list.txt

git checkout -- ./unit_list.txt
rm ./unit_list.txt

# check if unit have bom, show have
head -n 1 * | grep ate | cut -b "4-" | grep create

# select lower(a.object_name) from user_objects a where a.object_name not like 'SYS_%' order by 1 asc