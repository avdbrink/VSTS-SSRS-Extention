## Introduction
> VSTS Extension task to deploy Visual Studio Project - SQL Server Reporting Services entities.

## Description
> One or more Visual Studio projects from a solution, a project file or a complete folder, are deployed to a SQL Server Reporting Server Instance. 
> Supply a .rptproj file, a .sln file or a folder containing all your .rptproj files 

### How to Setup deploy
> Make sure you've added the source of your project to a build artifact and that this build artifact is linked to your release definition
> Note: Report projects do not require Build steps, what happens during a Visual Studio build is nothing more than a copy step of your sources to the build folder
> Point the "Project, Solution or Folder" entry to the project you are going to deploy. If you specify a folder, all report projects underneath that folder will be searched 
> for report projects.
> Note: make sure there is only one report project in your solution. Multiple report projects seem to cause an error during deployment. Multiple reports per project are no problem ofcourse.
> Use the Overwrtie project Config checkbox to supply the target server parameters. 
> Server URL requires the service url, usually this is: https://<computername>/reportserver
> When Overwrite Datasources and Overwrite Datasets are checked changes will be commited to the destination environment. Unckecking makes sure that once the datasource is setup on the target server
> it will not be overwritten by a new deployment. New datasources will however be added to the server when applicable
> "Create subfolders if multiple reports" has a special function: all reports will be stored in the Target folder, but when this checkbox is checked the deplyoment component will check if multiple 
> reports exist inside the project. In this case it will create a subfolder inside the target folder with the name of the project. All reports in this project will be stored in this new folder.
> This is done on a project base.

## Contribute
> * Contributions are welcome!
> * Submit bugs and help verify fixes
> [File an issue](https://github.com/avdbrink/VSTS-SSRS-Extention/issues)

## Latest Updates
> * None so far

## TODO:
> * multiple report projects in a single solution cause an error during deployment
