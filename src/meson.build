
custom_target('plugin-file-mail',
    input : 'BudgieMailnagApplet.plugin.in',
    output : 'BudgieMailnagApplet.plugin',
    command : ['cp', '@INPUT@', '@OUTPUT@'],
    install : true,
    install_dir: LIB_INSTALL_DIR,
)

applet_budgie_mailnag_sources = [
    'BudgieMailnagApplet.vala',
]

applet_budgie_mailnag_deps = [
    dep_gtk3,
    dep_glib,
    dep_peas,
    dep_budgie,
]

shared_library(
    'budgiemailnagapplet',
    applet_budgie_mailnag_sources,
    dependencies: applet_budgie_mailnag_deps,
    c_args: [
    ],
    install: true,
    install_dir: LIB_INSTALL_DIR,
)
