# compare units in ./psp/install_psp.sql and units in directory ./psp

cat schema/install_demo_obj.sql | grep @@ | cut -c 3- | tr -d "\r" | sort > ./unit_list.txt
# pbpaste > ./unit_list.txt
git add ./unit_list.txt

ls  schema | grep -v "install_demo_obj.sql" | sort > ./unit_list.txt
# ls  schema | grep -v "install_demo_obj.sql"| cut -d . -f 1 | sort > ./unit_list.txt
git diff -- ./unit_list.txt

git checkout -- ./unit_list.txt
rm ./unit_list.txt

# select * from user_dependencies a where a.referenced_owner = 'DEMO1'
# and a.referenced_name != a.name and a.referenced_name not in ('SRC_B', 'PC');

# check if unit have bom, show have
head -n 1 * | grep ate | cut -b "4-" | grep create