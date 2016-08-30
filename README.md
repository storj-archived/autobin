autobin
=======

Cross platform batch / shell scripts used to automatically build binaries for open pull requests and draft releases of the Storj [storjshare-gui](https://api.github.com/repos/Storj/storjshare-gui).

### Open Pull Request

Autobin creates a draft release for every open pull request and deletes the release as soon as the pull request is closed or merged. For each commit a new binary will be uploaded.

### Pull Request Comment

10 minutes after the last binary upload a comment with all binaries will be added to the pull request. Sometimes the binaries needs more than 10 minutes. In that case the comment will be modified and the missing binary will be added. If a new commit is detected the comment with the old binaries will be deleted and the 10 minutes timeout starts again.

### Draft a new release

Create a new release with the name "autobin draft release". Select base branch and release tag and save it as draft release. You can add a release discription any time. Autobin will build and upload binaries based on the selected branch and release tag. Be carefull with new commits. You have to delete the old binaries yourself to get new binaries.

Rename the release to detach the build scripts. There you have the new release ready to publish.

Setup
=====

Download the batch or shell script. Set environment variables Cert_File, Cert_Password (windows only)  and gh_token [github access token](https://github.com/settings/tokens) (repo privilage needed). 

### Build binaries for another repository

Change the github api url [like this](https://api.github.com/repos/Storj/storjshare-gui), modify the build steps and file extensions. Everything else should be fine.

### Dependencies

In order to run autobin you have to install git, curl, jq and the dependencies for the build steps. storjshare-gui needs nodejs and NSIS, npm@3 (windows only because of file path limits).

```
apt-get install git curl jq wget nodejs fakeroot
npm install -g n
n lts
```


License
-------

```
autobin - Cross platform batch / shell scripts used to automatically build binaries.
Copyright (C) 2016  Storj Labs, Inc

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
