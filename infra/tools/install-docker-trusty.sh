#if [ -z $1 ]; then
#    echo "first param is username!"
#    exit 1
#fi

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y linux-image-extra-$(uname -r)
sudo apt-get install -y apparmor
sudo apt-get install -y docker-engine
sudo service docker start
sudo groupadd docker
sudo usermod -aG docker pato

echo "Install successfull. Logout and back in to access docker without sudo"

#generate keypair
ssh-keygen -t rsa
# store it in ~/.ssh/

#create a vm in ARM
#Network Security Group > inbound rules: priority 900, source port *, dest port 2376, source any, protocol TCP, destination any

docker-machine create --driver generic --generic-ssh-key=/home/pato/.ssh/azure_pato --generic-ip-address=40.68.220.194 --generic-ssh-user="pato1" --generic-engine-port=2376 --generic-ssh-port=22 pato1

docker-machine create --driver generic --generic-ssh-key=/home/pato/.ssh/azure_pato --generic-ip-address=40.68.220.194 --generic-ssh-user="pato2" --generic-engine-port=2377 --generic-ssh-port=23 pato2
