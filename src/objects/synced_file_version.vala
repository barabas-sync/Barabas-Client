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
	[DBus (name = "be.ac.ua.comp.Barabas.SyncedFileVersion")]
	public class SyncedFileVersion : AResource
	{
		private Client.SyncedFileVersion client_synced_file_version;
	
		public SyncedFileVersion(Client.SyncedFileVersion sf_version)
		{
			this.client_synced_file_version = sf_version;
			sf_version.upload_started.connect(() => { upload_started(); });
			sf_version.upload_progressed.connect((a, b) => { upload_progressed(a, b); });
			sf_version.upload_stopped.connect(() => { upload_stopped(); });
		}

		public string get_name()
		{
			return client_synced_file_version.name;
		}
		
		/*public DateTime get_datetimeedited()
		{
			return client_synced_file_version.datetimeEdited;
		}*/

		protected override void do_register(string path,
		                                    DBusConnection connection) throws GLib.IOError
		{
			connection.register_object(path, this);
		}
		
		public signal void upload_started();
		public signal void upload_progressed(int64 progress, int64 total);
		public signal void upload_stopped();
	}
}
	
