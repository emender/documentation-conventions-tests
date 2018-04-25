# Documentation Conventions Tests

## What it is
This is a test suite for [Emender](https://github.com/emender/emender) framework. It consists of two tests: Documentation Guidelines Test and Word Usage Test. One tests documentation against the existing guidelines, checks spelling etc. Another one checks for correct word usage in specific context. The tests generate the results in multiple formats and give you an extensive summary.

## How to run it
To run the test suite locally, follow these steps.
1. Download the repository to your local machine. You don't need to have the test and documentation in the same folder. In fact, it's advisable not to.
2. Download the documentation files into a separate folder. This folder must include:
	* results.master
		* directory containing "publican.cfg" and possibly "master.adoc".
	* publican.cfg
		* config file for your documentation, should have a "mainfile" parameter with the name of the master file, e.g. "mainfile: master"
		* master file is located in the "your_language/" subfolder, e.g. "en-US/"
	* results.cwd
		* file containing documentation directory
3. Documentation folder might or might not include "results.includes". It specifies which files (apart from "master.adoc") should be included in the tests if any.
4. Obviously, you also need the documentation itself.
5. Before running the test make sure to install Aspell dictionary.	
~~~~~~~~
sudo dnf install aspell	
~~~~~~~~ 
Once it's installed, run the script "generate_dictionary.sh" in the test folder. It will generate "aspell.txt" with the dictionary words.
6. You'll also need Lua installed.
~~~~~~~~
sudo dnf install lua
~~~~~~~~
7. Last piece is libraries. These can be downloaded [here](https://github.com/emender/emender-lib/tree/master/lib). You need "docbook.lua", "publican.lua" and "xml.lua". When you first run the tests, it will give you an error message and you'll see the path at which these libraries should be placed.
8. The external services (such as whitelist, blacklist, glossary etc.) are not required, but they give some extra information + have a wider selection of words. Unlike Aspell, these are tailored for the Red Hat documentation team and will have all the latest and greatest updates.
9. You're ready to run the tests! Through Terminal navigate to the documentation folder. Then type `emend path_to_test_folder/DocumentationConventions.lua` and see the results. You can check available Emender parameters [here](https://github.com/emender/emender/blob/master/doc/man/man1/emend.1.pod).

## Extra

Author of "atomic_typos.txt" is Stephen Wadeley (thanks!).

## License

*documentation-conventions-tests* is free software: you can redistribute it
and/or modify it under the terms of the GNU General Public License as published
by the Free Software Foundation; version 3 of the License.

*documentation-conventions-tests* is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE. See the [GNU General Public
License](http://www.gnu.org/licenses/) for more details.
