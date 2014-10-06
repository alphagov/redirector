
sh tools/known_domains.sh

while read line
do
	dig $line | grep 46.137.92.159
done < cache/known_domains | tee cache/still_pointing_at_ec2

echo $(wc -l cache/still_pointing_at_ec2 | awk '{print $1}') domains still pointing at EC2