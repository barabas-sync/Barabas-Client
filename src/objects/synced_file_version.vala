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
		}
		
		public int64 get_id()
		{
			return client_synced_file_version.ID;
		}
		
		public int get_datetimeedited()
		{
			return client_synced_file_version.datetimeEdited;
		}
		
		protected override void do_register(string path, DBusConnection connection)
		{
			connection.register_object(path, this);
		}
	}
}
	
