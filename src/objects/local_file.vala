/**
    This file is part of Barabas DBUS Client.

	Copyright (C) 2011 Nathan Samson
 
    Barabas DBUS Client is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Barabas DBUS Client is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Barabas DBUS Client.  If not, see <http://www.gnu.org/licenses/>.
*/

namespace Barabas.DBus.Server
{
	[DBus (name = "be.ac.ua.comp.Barabas.LocalFile")]
	public class LocalFile : AResource
	{
		private Barabas.Client.LocalFile client_local_file;
		private Barabas.Client.Database database;
		
		private SyncedFile synced_file;
		private uint dbus_ref_count;
	
		public LocalFile(Barabas.Client.LocalFile client_local_file,
		                 Barabas.Client.Database database)
		{
			this.client_local_file = client_local_file;
			this.client_local_file.synced.connect(on_synced);
			this.database = database;
			
			this.synced_file = null;
		}
		
		public string get_uri()
		{
			return this.client_local_file.uri;
		}
		
		public string get_display_name()
		{
			return this.client_local_file.display_name;
		}
		
		public void sync()
		{
			client_local_file.sync(database);
		}
		
		public bool is_synced()
		{
			return client_local_file.is_synced();
		}
		
		public signal void synced();
		
		internal void acquire()
		{
			dbus_ref_count++;
		}
		
		public void release()
		{
			dbus_ref_count--;
			
			if (dbus_ref_count == 0)
			{
				released();
				unpublish();
			}
		}
		
		public signal void released();

		internal override void publish(string path, DBusConnection connection) throws GLib.IOError
		{
			base.publish(path, connection);
		
			if (is_synced())
			{
				stdout.printf("Register\n");
				Client.SyncedFile client_synced_file =
				    Client.SyncedFile.from_ID(database,
				                              client_local_file.syncedID);
				synced_file = new SyncedFile(client_synced_file);
				synced_file.publish(dbus_path + "/synced_file", connection);
			}
		}
		
		internal override void unpublish()
		{
			base.unpublish();
			if (synced_file != null)
			{
				synced_file.unpublish();
			}
		}
		
		private void on_synced(Client.SyncedFile client_synced_file)
		{
			try
			{
				synced_file = new SyncedFile(client_synced_file);
				synced_file.publish(dbus_path + "/synced_file", dbus_connection);
				synced();
			}
			catch (GLib.IOError error)
			{
				// FIXME: is their something sensible we can do?
			}
		}
		
		protected override uint do_register(string path,
		                                    DBusConnection connection) throws GLib.IOError
		{
			return connection.register_object(path, this);
		}
	}
}
