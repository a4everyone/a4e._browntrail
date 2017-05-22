Guidelines for creating docker files, built by Ansible:

The folder name should match the image name.
Dockerfile and .dockerignore are treated as jinja2 templates
There is some boilerplate code in .dockerignore that includes all referenced external apps and the <<common_paths.dockerfiles>>/<<img_name>> folder. Use it
The automated build templates out Dockerfile and .dockerignore to $A4E_PROJ_ROOT and uses it as a build context
If you wish to create a base image, the folder name should be <<image name>>-base
In the dockerfile, put any paths in ARG statements and use jinja2 to refer to paths defined in common-paths.yml as much as possible
If you want your dockerfile to use an app that is downloaded separately, describe it in software-versions.yml and refer to it in an ARG from the dockerfile.
  The automated image build scans the Dockerfile for such referenes and injects the right software versions, downloading them as necessary.
Any dependencies on a4e java libraries must be described in <<build_configs>>/<<image_name>>.yml. 
  By convention they should be built in <<build_configs>>/.build/lib/java. The .build folder is not maintained by git

TODO:
  Add optional step to build the base image as a prerequisite to the image?
  Inject base image versions
  Versioned images
  Code snipped replacements in Dockerfile - e.g. {{ install.Java }} inserts a whole snippet that installs java?
  Git pulls/checkouts, git version as ENV in the image
  Putting tags in git upon deploy
  Lab image - build matlab as a prebuild step
  Versions for a4e libraries - similar to versions we have for external software?
