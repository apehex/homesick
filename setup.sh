# Package Configuration #
#########################
cp -r ./dotfiles/ ~/.dotfiles/
cd ~/.dotfiles/

# Sublime Text #
################
wget -q -O - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list

# Brave Browser #
#################
# wget https://s3-us-west-2.amazonaws.com/brave-apt/keys.asc | sudo apt-key add -
# echo "deb [arch=amd64] https://s3-us-west-2.amazonaws.com/brave-apt `lsb_release -sc` main" | sudo tee -a /etc/apt/sources.list.d/brave-browser.list

# Google Chrome #
#################
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list

# Google Cloud #
################
GCLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb http://packages.cloud.google.com/apt $GCLOUD_SDK_REPO main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list

# Install packages #
####################
sudo apt update
cat profiles/core.packages | xargs sudo apt-get install
#cat profiles/dev.packages | xargs sudo apt-get install
