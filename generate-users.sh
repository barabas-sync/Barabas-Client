
for i in $(seq 1 1000); do
	name=$(</dev/urandom tr -dc A-Za-z0-9 | head -c8);
	echo $name
done
