/*
 * This file is part of budgie-mailnag-applet
 *
 * Copyright © 2017 Mehmet Ali İLGAR <mehmet.ali@milgar.net>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

namespace Mailnag {

public class Plugin : Budgie.Plugin, Peas.ExtensionBase
{
    public Budgie.Applet get_panel_widget(string uuid)
    {
        return new Applet();
    }
}

const string MAILNAG_BUS_NAME = "mailnag.MailnagService";
const string MAILNAG_BUS_PATH = "/mailnag/MailnagService";


[DBus (name="mailnag.MailnagService")]
public interface MailnagIface : Object
{
    public abstract async void check_for_mails() throws IOError;
    public abstract async void shutdown() throws IOError;
    public abstract async void mark_mail_as_read(string mail_id) throws IOError;

    public abstract void get_mails(out HashTable<string,Variant>[] mails);
    public abstract void get_mail_count(out uint count);

    public abstract signal void mails_added (HashTable<string,Variant>[] new_mails, HashTable<string,Variant>[] all_mails);
    public abstract signal void mails_removed (HashTable<string,Variant>[] remaining_mails);
}

public class Applet : Budgie.Applet
{
    public Gtk.Image widget { protected set; public get; }

    /* Use this to register popovers with the panel system */
    private unowned Budgie.PopoverManager? manager = null;

    /** EventBox for popover management */
    public Gtk.EventBox? ebox;

    public Budgie.Popover popover;

    private MailnagIface? mailnag;

    private uint mail_count;
    private Gtk.Label unread_label;
    private Gtk.Label mail_count_label;
    private Gtk.ListBox mail_listbox;

    private HashTable<string,Variant>[] mails;

    public Applet()
    {
        Gtk.Box container_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        widget = new Gtk.Image.from_icon_name("mail-unread-symbolic", Gtk.IconSize.MENU);
        mail_count_label = new Gtk.Label("(-)");
        ebox = new Gtk.EventBox();
        container_box.add(widget);
        container_box.pack_start(mail_count_label, false, false, 6);
        ebox.add(container_box);
        ebox.margin = 0;
        ebox.border_width = 0;
        add(ebox);

        /* Sort out our popover */
        this.create_mailnag_popover();

        ebox.button_press_event.connect((e)=> {
            /* Not primary button? Good bye! */
            if (e.button != 1) {
                return Gdk.EVENT_PROPAGATE;
            }
            /* Hide if already showing */
            if (this.popover.get_visible()) {
                this.popover.hide();
            } else {
                /* Not showing, so show it.. */

                this.repopulate_popover();
                this.manager.show_popover(ebox);
            }
            return Gdk.EVENT_STOP;
        });

        show_all();

        try {
            mailnag = Bus.get_proxy_sync (BusType.SESSION, MAILNAG_BUS_NAME, MAILNAG_BUS_PATH);
            if(mailnag != null){
                this.get_mails();
                mailnag.get_mail_count(out this.mail_count);
                update_applet_label(this.mail_count);

                mailnag.mails_added.connect((new_mails, all_mails) => {
                    this.mails = all_mails;
                    update_applet_label(all_mails.length);
                });

                mailnag.mails_removed.connect((remaining_mails) => {
                    this.mails = remaining_mails;
                    update_applet_label(remaining_mails.length);
                });
            }
        } catch (IOError e) {
            print(e.message);
        }
    }

    /**
     * Create the GtkPopover to display on primary click action
     */
    private void create_mailnag_popover()
    {
        popover = new Budgie.Popover(ebox);
        Gtk.Box? popover_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        popover.add(popover_box);
        popover_box.margin = 6;


        this.mail_listbox = new Gtk.ListBox();
        popover_box.pack_start(this.mail_listbox, false, false, 1);

        popover_box.pack_start(new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false, false, 1);

        unread_label = new Gtk.Label("");
        unread_label.set_ellipsize (Pango.EllipsizeMode.END);
        unread_label.set_alignment(0, 0.5f);
        popover_box.pack_start(unread_label, false, false, 1);

        Gtk.Button refresh_button = new Gtk.Button.with_label("Refresh");
        popover_box.pack_start(refresh_button, false, false, 1);

        refresh_button.clicked.connect (() => {
            new Thread<void*> (null, () => {
                mailnag.check_for_mails.begin();
                return null;
            });
        });

        popover.get_child().show_all();
    }

    void update_applet_label(uint mail_count) {
        mail_count_label.label = "("+mail_count.to_string()+")";
    }

    void repopulate_popover() {

        GLib.List<weak Gtk.Widget> children = this.mail_listbox.get_children ();
        foreach (Gtk.Widget element in children)
            this.mail_listbox.remove(element);

        for (int i = 0; i < this.mails.length && i <10; i++) {
            Gtk.Label label = new Gtk.Label(this.mails[i].get("subject").get_string());
            label.set_ellipsize (Pango.EllipsizeMode.END);
            label.set_alignment(0, 0.5f);
            label.max_width_chars = 40;

            this.mail_listbox.add(label);
        }
        this.mail_listbox.show_all();

        mailnag.get_mail_count(out this.mail_count);
        unread_label.label = "Unread Mail Count: " + this.mail_count.to_string();
    }

    public void get_mails() {
        new Thread<void*> (null, () => {
            mailnag.get_mails(out this.mails);
            return null;
        });
    }

    public override void update_popovers(Budgie.PopoverManager? manager)
    {
        manager.register_popover(this.ebox, this.popover);
        this.manager = manager;
    }
}

void print(string? message){
    if (message == null) message = "";
    stdout.printf ("Budgie-Mailnag: %s\n", message);
}

}

[ModuleInit]
public void peas_register_types(TypeModule module)
{
    // boilerplate - all modules need this
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(Budgie.Plugin), typeof(Mailnag.Plugin));
}
