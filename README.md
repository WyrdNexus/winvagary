# Vagrant FullAuto Laravel Dev Environment
Uses ./config.yml to configure and deploy a local VM for development. 
Note the config defines two crical properties:
* project: `project_name`
* projects_dir: `C:/dev/Projects`

Launch will look for a .env file in `C:/dev/Projects/project_name.env` from which to load all relevant configuration details. A sample is included here at `./.env-example`.

## Requirements

* Windows Hyper-V disabled
* Windows Ssh-Agent enabled or manual
	* start agent and add your github key
* Latest VirtualBox
* Vagrant vbguest plugin
* git deploy token
* vagrant commands run from a propmpt with elevated permissions

### Windows Hyper-V

* [START-key]
* type "features"
* Run "Turn Windows features on or off"
* Uncheck Hyper-V
* restart machine

### Windows Ssh-Agent

* [START-key]
* type "services"
* Run "Services" dialog
* Find "OpenSSH Authentication Agent"
* Right-click, properties
* Change "startup type" to "Manual"
* Apply, OK, Close

**Start the agent, and add your github key**
```
ssh-agent
ssh-add C:\Users\[username]\.ssh\github_private_key
```

### VirtualBox

* [VirtualBox](https://www.virtualbox.org/)
    * version 6.1 as of authoring this doc

### Vagrant

Automatically installs 

* vagrant-vbguest
    * `vagrant plugin install vagrant-vbguest`

### Git Token

Add your github deploy token to your local git config

* `git config --global github.accesstoken '[TOKEN]'`

### Elevated permissions

* Pick your CLI (cmd, powershell, conemu), right-click and run as Admin.