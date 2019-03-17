[![Build Status](
https://travis-ci.org/nickrusso42518/mkfd.svg?branch=master)](
https://travis-ci.org/nickrusso42518/mkfd)

[![published](
http://cs.co/codeex-badge)](
https://developer.cisco.com/codeexchange/github/repo/nickrusso42518/mkfd)

# role : Make Files and Docs (mkfd)
This role defines a general-purpose text templating engine. Plays that include
this role will supply their own variables and templates in the proper
locations. The role handles all the heavy-lifting and error checking
associated with correctly templating text files. The tool can also
handle infrastructure updates, configuration integrity via hashing, and
automated documentation generation using LaTeX.

> Contact information: \
> Email:    njrusmc@gmail.com \
> Twitter:  @nickrusso42518

  * [Supported platforms](#supported-platforms)
  * [Hosts](#hosts)
  * [LaTeX installation](#latex-installation)
  * [Role defaults](#role-defaults)
  * [Role variables](#role-variables)
  * [Role handlers](#role-handlers)
  * [Role templates](#role-templates)
  * [Design guidance](#design-guidance)

## Supported platforms
This playbook does not log into any devices and only runs locally on the
control machine. It is a perfect choice for risk-averse/conservative
organizations that are not willing to automate their production devices yet.

Control machine information:
```
$ cat /etc/redhat-release
Red Hat Enterprise Linux Server release 7.4 (Maipo)

$ uname -a
Linux ip-10-125-0-100.ec2.internal 3.10.0-693.el7.x86_64 #1 SMP
  Thu Jul 6 19:56:57 EDT 2017 x86_64 x86_64 x86_64 GNU/Linux

$ ansible --version
ansible 2.7.7
  config file = /etc/ansible/ansible.cfg
  configured module search path = ['/usr/share/my_modules']
  ansible python module location =
    /home/ec2-user/environments/ps-ans/lib64/python3.6/site-packages/ansible
  executable location = /home/ec2-user/environments/ps-ans/bin/ansible
  python version = 3.6.7 (default, Dec  5 2018, 15:02:05)
    [GCC 4.8.5 20150623 (Red Hat 4.8.5-36)]

## Hosts
Typically this role is included in a play that only contains the control
machine. No network connectivity is required for the role to work, although
copying files from the control machine to other devices will require SCP or
some other mechanism of file transfer.

## LaTeX installation
Users who want to take advantage of this role's ability to create PDFs
along with text files will need to install TeX Live. After installation,
follow the steps to update your `PATH` variable so that the shell command
`pdflatex` functions.

> Download TeX Live:
> https://www.tug.org/texlive/quickinstall.html

Last, update the `texmf.cnf` file contained in the correct location
(the distribution year changes each year), with `openout_any = a` which
allows `pdflatex` to create output files in a location outside of the
directory structure where the source document exists. This is because
PDFs are written to the proper entity folders as files are shuffled around.

Those not interested in using the documentation feature do not need to
install LaTeX to use the rest of the role functions. Be sure that `doc_name`
is always set to `false`, which is a role default, to avoid any LaTeX
false negatives. Users can also `export openout_any=a` as an environment
variable, which works nicely for CI/CD pipelines.

```
$ cat /usr/local/texlive/2018/texmf.cnf
% [comments from the Tex Live maintainers]
openout_any = a
```

## Role defaults
There are several variables defined in the role as defaults. Most of these are
intended to be overwritten and are only defined as defaults so that the tasks
do not fail catastrophically.

  * `entity_list`: By far the most important variable, this contains the list of
    entities to be templated. The word "entity" is synonymous with the word
    "system" in that the length of this list should be the number of systems
    to template. The entity list is not concerned with the composition of
    each system. Each element in the list should be a dictionary which contains
    values relevant to that system. The only key that is required is `id`
    which is used to uniquely identify the system; it can hold any value. __The
    default setting for this variable is the empty list [],__ which causes
    the role do gracefully do nothing when it is not correctly overridden by
    playbook `host_vars/localhost`, `group_vars/control`, or something similar.
    The directory structure will still be initialized, but the lack of entities
    means that no templated files can be generated. Example `entity_list` below.

    ```
    ---
    entity_list:
    - id: system1
      subnet: 10.0.1.0/24
      poc: john doe
      bgp_asn: 65001
    - id: system2
      subnet: 10.0.2.0/24
      poc: jane smith
      bgp_asn: 65002
    ...
    ```

  * `zip_format`: Both the compression type and file extension of the archive.
    The role default is `zip` for Windows compatibility. Any option supported
    by the `archive` module is supported here, based on current Ansible
    version. Use `ansible-doc archive` to see the list of options.

  * `debug_level`: The debug verbosity required in order to see role-level
    task debugging during execution. Set to __1 by default__ and not commonly
    overridden, this allows debug to be revealed with the `-v` option when
    `ansible-playbook` is invoked. Debugging generally prints the value of
    variables processed by the role to stdout for troubleshooting/logging.

  * `current_user`: Performs an environment lookup on the `USER` variable
    and stores the result. This string can be used in templates and playbooks
    for comments or troubleshooting, and works nicely when paired with `DTG`.
    For example: `by "{{ current_user }}" at "{{ DTG }}"`

  * `file_mode`: The role generates a number of files (discussed more later),
    and the permissions of the files can be set when the files are created.
    The default value is __0444__ which implies all users can read it, but
    no one can edit it. This is not commonly overridden, but if it is, a value
    of __0664__ can be used to enable write permissions to the owner and group
    members. This might be useful when configurations are being created
    based on limited information (read: need to deliver fast) and this
    tool is being used as a 90% solution. Note that post-processing changes to
    output files will invalidate the machine-generated SHA-256 hashes.

  * `make_zip`: A true/false question which controls whether to archive all of
    the resulting text files into a single Windows ZIP bundle. When set to yes,
    all source files/folders are deleted, leaving only the final bundle.
    The default value is no, which does not create a bundle and retains
    all source files/folders. Answering `false` is an appropriate option for
    testing and development to rapidly check the output files for correctness.
    Answering `true` is an appropriate option for production deliverables.
    This variable is commonly overloaded within the playbook variables.

  * `zip_name`: Optional parameter to provide an alternate, potentially more
    descriptive name for the ZIP file output generated when `make_zip` is
    true. By default, the string "archive" is used.

  * `doc_name`: When specified, the role looks for a jinja2 file with this
    basename with the intent of creating a PDF document using LaTeX. The
    file must be present in a playbook directory called `doc_inputs/`. The
    utility is called `pdflatex` (https://www.tug.org/applications/pdftex/).
    Note: Generally speaking, only a `.pdf` file is accessible after running
    this utility, which is appropriate for distribution. When `pdflatex`
    is invoked, it generates many intermediate files, such as:
      * `.toc`: Table of contents
      * `.lot`: List of tables
      * `.lof`: List of figures
      * `.aux`: Auxiliary compilation data
      * `.tex`: LaTeX source file
      * `.out`: Sectional information about outlines

  * `keep_tex`: When `doc_name` is specified, the `.tex` file generated by
    the templater will be retained. This is only valuable for troubleshooting
    that the jinja2 templating process succeeded before typesetting the file
    into LaTeX using `pdflatex`. By default, this file is removed as the
    end-users should never see it.

  * `skip_sha256`: A true/false question that allows an operator to skip
    the hashing of output files. The value is `false` by default since
    security should be both assumed and integration with any provisioning
    system. Setting this value to `true` is limited to cases where it is
    certain that configurations must be hand-edited after generation to meet
    a specific customer demand. These cases are very rare.

  * `scp`: Nested dictionary containing two subkeys below.
    * `user`: The SCP username that can write files to the SCP server.
    * `host`: The SCP server FQDN/IP address. Under its root directory, a
      directory called `racc/` should be created. This is where the archives
      generated by this playbook are copied.

## Role variables
Given the high priority of role variables within Ansible, these are used
for constant values. Any set of known-in-advanced and seldom changing
information can be enumerated here to offload the complexity of
defining constants at the playbook level. Defining complex data
structures, like nested dictionaries, lists of dictionaries, etc ...
can significantly reduce the playbook level variable input process.

## Role tasks
The tasks begin by checking that all entities have an `id` field. The output
is verbose and all entries are checked, even if there are failures early in
the list. The list indices (counting from 0) indicate where the failures occur,
simplifying the remediation process for the playbook designer.

Following this check, some other error checking around directory/file
presence is conducted. The main work is done by populating the following
directories with templates:

  * `config_templates/`: Place config file templates here. Each one of these
    files is considered a component of an entity. If an entity contains a
    router, a switch, and a firewall, there should be one template for each
    in this folder. That will create a total of 3 configurations for a given
    entity. Nested iteration executes the `template` module so that the
    total number of configuration files generated is as follows:
    __number of entities * number of files in config_templates/__
    Given 3 devices in an entity across 2 entities would yield 6 files total.

  * `infra_templates/`: Place infrastructure templates here. These templates
    embed their own iteration, typically iterating over the `entity_list`,
    to write information that assists updating the infrastructure to support
    the addition of these new entities. For example, if 4 new carrier POPs are
    provisioned, an infra template might populate a CSV to be imported into
    the AAA server to add these new systems, rather than doing it manually.
    __This folder is only created when infra templates are defined for a
    playbook that inherits this role. This keeps the delivery bundle clean.__

  * `doc_inputs/`: Place any files related to PDF generation here. At a
    minimum, it should include a `doc_name`.j2 file which is used to build
    a documentation PDF (optional). This directory should also house any images
    or other content referenced by the template required for the final PDF
    generation.

As it relates to playbook specific error checking, each playbook can
contribute a `pre_check.yml` file in the playbook directory. This is a simple
task list to be run immediate after the role-based error checking, such as
ensuring there are no duplicate `id` fields. If the file is absent, no
playbook specific error checking is done. Note that playbook specific error
checking can be done before or after the role inclusion, but when done before
inclusion, role variables cannot be accessed.

Additionally, an optional `pre_config.yml` file can be included for each
iteration of generating configuration templates. This file can be used for
additional variable declaration and processing to remove it from the templates.
This is useful for playbooks that have many templates all referencing a shared
set of common variables. If it is not specified, any variable
processing logic must be directly embedded in jinja2 templates. This
works nicely for small projects with few templates and/or few shared
variables across templates. For larger projects with more dependencies
and shared data, including a `pre_config.yml` file is recommended.

Output files generated by the playbook are written to the files/ folder. Each
entitys configuration files are contained in a subfolder "id\_dtg". For
example, an entity with id "system1" and DTG "20171106T122919Z" would have
its configs in __files/system1\_20171106T122919Z/__ for easy organization.

The configuration files themselves are in the format "id\_template\_dtg". For
example, "system1\_EdgeRouter\_20171106T122919Z.txt". The files are always
saved with a .txt extension for easy Windows readability and identification.

Once all the files are created, the SHA-256 checksums are calculated for each
file and rolled up into a CSV for easy viewing. This checksum CSV is included
in the bundle, but for security reasons, should also be distributed to the
end-users via some other method.

Archives are written to the archives/ folder and have a format of
bundle\_dtg. For example, a templater that executes at 20171106T122919Z would
generate an archive `archives/archive_20171106T122919Z.zip` file, assuming
a custom `zip_name` was not defined.

## Role handlers
Handlers for this role are only invoked when `make_zip` is yes an the bundle
changes. The handlers simply delete any residual folders left behind by the
`archive` module.

## Role templates
The role only comes with one template which is used for writing SHA-256
checksums to a CSV file. This is common to any templating process and is
highly generic, and thus need not be implemented in every playbook.

## Design guidance
Populating the `config_templates/` and `infra_templates/` directories with the
relevant templates for a given objective is the responsibility of the playbook
designer. Here are some tips:

  * Configuration templates typically have these attributes:
    * Begin with `#jinja2: newline_sequence:'\r\n'` for easy Windows viewing
    * Assign `item[0]` to a new var `entity` for simplified var substitution
    * Do not contain iteration; this is handled by the templater tasks
    * Try to match the exact text, including white space, of the device
    * Embed system specific comments for easy operator troubleshooting
    * Generally limited to simple variable substitution

  * Infrastructure templates typically have these attributes:
    * Contain single-depth iteration over the `entity_list`
    * May deal with complex CSV files or other formats as required
    * Are optional. When not supplied, the role gracefully skips the process
