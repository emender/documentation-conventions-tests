#!/bin/bash

DOC_DIR=""
EMENDER_DIR=""
EMENDER_PATH=""

for arg in "$@"
do
    if [[ $arg = "--XdocDir="* ]]
    then
        DOC_DIR=$(echo $arg | sed "s/--XdocDir=//")
        DOC_DIR=${DOC_DIR%/}
    elif [[ $arg = "--XemenderDir="* ]]
    then
        EMENDER_DIR=$(echo $arg | sed "s/--XemenderDir=//")
        EMENDER_DIR=${EMENDER_DIR%/}
        EMENDER_PATH=${EMENDER_DIR}/emend
    fi
done

if [[ $DOC_DIR = "" ]]
then
    DOC_DIR=$(echo $PWD)
    DOC_DIR=${DOC_DIR%/}
fi

if [[ $EMENDER_PATH = "" ]]
then
    EMENDER_PATH=emend
fi

export TERM=linux
TEST_DIR=$(dirname $0)
PATH_TO_TEST=${TEST_DIR}/DocumentationConventions.lua
DOC_FORMAT=""
 
function read_doc_format {
    pushd ${DOC_DIR} 2> /dev/null
    if [[ -f "master.adoc" ]]
    then
        DOC_FORMAT="AsciiDoc"
    elif [[ -f "publican.cfg" ]]
    then
        DOC_FORMAT="DocBook"
    else
        DOC_FORMAT="unknown"
    fi
    popd 2> /dev/null
}

function asciidoc2docbook {
    rm -rf en-US
    rm -f publican.cfg
    rm -f results.*
    rm -rf bootstrap
    rm -rf css
    rm -rf flotr
    rm -rf js
    rm -f yoana.css
    cwd=$(echo $PWD)
    pushd ${DOC_DIR} 2> /dev/null
    # Convert master.adoc to DocBook 4.5 format.
    asciidoctor -d book -b docbook45 master.adoc
    publican create --name master
    cp -r master/en-US $cwd
    cp master/publican.cfg $cwd
    mv master.xml $cwd/en-US
    rm -r master
    popd 2> /dev/null
}

function add_common_content {
    if [[ -d "~/emender-rhel/test" ]]
    then
        mkdir -p en-US/Common_Content
        cp ~/emender-rhel/test/Legal_Notice.xml en-US/Common_Content
        cp ~/emender-rhel/test/Conventions.xml en-US/Common_Content
        cp ~/emender-rhel/test/Feedback.xml en-US/Common_Content
        cp ~/emender-rhel/test/Program_Listing.xml en-US/Common_Content
    fi
}

read_doc_format

if [[ $DOC_FORMAT == "AsciiDoc" ]]
then
    asciidoc2docbook
    add_common_content
elif [[ $DOC_FORMAT == "DocBook" ]]
then
    if [[ ! -d "en-US/Common_Content" ]]
    then
        add_common_content
    fi
fi

if [[ $EMENDER_DIR = "" ]]
then
    OPTIONS="--XtestDir=${TEST_DIR}"
else
    OPTIONS="--XtestDir=${TEST_DIR} --XemenderDir=${EMENDER_DIR}"
fi

OUTPUT="-o results.xml -o results.junit -o results.txt -o results.html -o results.json -o results.summary -o results.message"
${EMENDER_PATH} -c ${PATH_TO_TEST} ${OPTIONS} $@ ${OUTPUT}