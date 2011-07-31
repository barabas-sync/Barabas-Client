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
	
		public LocalFile(Barabas.Client.LocalFile client_local_file,
		                 Barabas.Client.Database database)
		{
			this.client_local_file = client_local_file;
			this.client_local_file.synced.connect((file) => { synced(); });
			this.database = database;
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

		internal override void publish(string path, DBusConnection connection)
		{
			base.publish(path, connection);
		
			if (is_synced())
			{
				stdout.printf("Register\n");
				Client.SyncedFile client_synced_file =
				    Client.SyncedFile.from_remote(database,
				                                  client_local_file.syncedID);
				SyncedFile synced_file = new SyncedFile(client_synced_file);
				dbus_connection.register_object(dbus_path + "/synced_file", synced_file);
			}
			
			stdout.printf("Connect to register\n");
			client_local_file.synced.connect(on_synced);
		}
		
		internal void unpublish()
		{
			base.unpublish();
			if (is_synced())
			{
				//TODO: unpublish synced file
			}
		}
		
		private void on_synced(Client.SyncedFile client_synced_file)
		{
			stdout.printf("Register ON SYNC\n");
			SyncedFile synced_file = new SyncedFile(client_synced_file);
			dbus_connection.register_object(dbus_path + "/synced_file", synced_file);
		}
		
		protected override void do_register(string path, DBusConnection connection)
		{
			connection.register_object(path, this);
		}
	}
}
