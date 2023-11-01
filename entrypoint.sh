#!/bin/bash
# This script is based on the work by Frederik Held
# It has been modified to:
#
#   1. pull the latest version of PlantUML from SourceForge
#   2. remove the dependency on Docker
#
# By executing directly on the runner, we can use the latest version of Ubuntu automatically,
# speeding up the process and removing the need to maintain a docker image.

local_input_dir=$INPUT_DIR
local_output_dir="output"

artifacts_repo=""
if [[ ${WIKI_TOKEN} != "" ]]; then
	artifacts_repo="https://${WIKI_TOKEN}@github.com/${GITHUB_REPOSITORY}.wiki.git"
elif [[ ${GHAPP_TOKEN} != "" ]]; then
	artifacts_repo="https://x-access-token:${GHAPP_TOKEN}@github.com/${GITHUB_REPOSITORY}.wiki.git"
else
	echo "No token defined!"
	exit 1
fi

artifacts_upload_dir=$OUTPUT_DIR

git config --global user.name "$GITHUB_ACTOR"
git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"

echo "=> Install graphviz ..."
sudo apt-get update && sudo apt-get install -y graphviz
echo "---"

echo "=> Downloading PlantUML Java app ..."
if [ ! -f plantuml.jar ]; then
	wget --quiet -O plantuml.zip https://sourceforge.net/projects/plantuml/files/latest/download
	unzip plantuml.zip
fi
echo "---"

echo "=> Preparing output dir $local_output_dir..."
mkdir -p "$local_output_dir"
echo "---"

# Run PlantUML for each file path:
echo "=> Starting render process in $local_input_dir..."
java -jar plantuml.jar -charset UTF-8 "$JAVA_ARGS" -t"$IMAGE_TYPE" -output "${GITHUB_WORKSPACE}/${local_output_dir}" "${GITHUB_WORKSPACE}/${local_input_dir}"
echo "---"

echo "=> Generated files:"
# ls -l "${GITHUB_WORKSPACE}/${output_filepath}"
ls -l "${GITHUB_WORKSPACE}/${local_output_dir}"
echo "---"

echo "=> Cleaning up possible left-overs from another render step ..."
rm -r "${GITHUB_WORKSPACE}/artifacts_repo"
echo "---"

echo "=> Cloning wiki repository ..."
git clone "$artifacts_repo" "${GITHUB_WORKSPACE}/artifacts_repo"
if [ $? -gt 0 ]; then
	echo "   ERROR: Could not clone repo."
	echo "   Note: you need to initialize the wiki by creating at least one page before you can use this action!"
	exit 1
fi
echo "---"

echo "=> Moving generated files to /${artifacts_upload_dir} in wiki repo ..."
mkdir -p "${GITHUB_WORKSPACE}/artifacts_repo/${artifacts_upload_dir}"
cp -rf "${GITHUB_WORKSPACE}/${local_output_dir}/." "${GITHUB_WORKSPACE}/artifacts_repo/${artifacts_upload_dir}"
echo "---"

echo "=> Committing artifacts ..."
cd "${GITHUB_WORKSPACE}/artifacts_repo"

# git status
git add .

if git commit -m"Auto-generated PlantUML diagrams"; then
	echo "=> Pushing artifacts ..."
	git push
	if [ $? -gt 0 ]; then
		echo "   ERROR: Could not push to repo."
		exit 1
	fi
else
	echo "(i) Nothing changed since previous build. The wiki is already up to date and therefore nothing is being pushed."
fi
echo "---"

# Print success message:
echo "=> Done."
