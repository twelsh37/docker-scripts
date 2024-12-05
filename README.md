# docker-scripts

This is a collection of scripts that I use to create and destroy My supabase install.

It comprises of 4 scripts that carry out various different tasks.

| Script Name                     | Description                                                                 |
|---------------------------------|-----------------------------------------------------------------------------|
| create-supabase-environment.ps1 | Powershell script that creates a local install of Supabase using Docker     |
| remove-supabase-environment.ps1 | Removes Supabase bucket and installation                                    |
| docker-cleanup-selective.ps1    | PowerShell script to remove selected Docker containers, images, and volumes |
| docker-cleanup-selective.sh     | Bash script to remove selected Docker containers, images, and volumes       |

##Example of docker-cleanup-selective.ps1 running
### docker-cleanup-selective.ps1
This is a Windows PowerShell script that will clean up docker containers and volumes selectively based on the container names.
The user is presented with a list of running Containers and asked to select which ones to remove.

![docker-cleanup-selective.ps1 Confirmation](https://github.com/user-attachments/assets/043afa0a-b4cb-4d04-8a68-4bba9b90c80c)
![docker-cleanup-selective.ps1 Deletions](https://github.com/user-attachments/assets/b8716a9c-2a84-457b-a51a-dffd15f4a1c4)


## docker-cleanup-selective.sh
This is a Linux/UNIX/Mac OSX shell script that will clean up docker containers and volumes selectively based on the container names.
The user is presented with a list of running Containers and asked to select which ones to remove.

