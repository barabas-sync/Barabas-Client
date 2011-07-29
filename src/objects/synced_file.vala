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
	[DBus (name = "be.ac.ua.comp.Barabas.SyncedFile")]
	public class SyncedFile : AResource
	{
		private Barabas.Client.SyncedFile client_synced_file;
	
		public SyncedFile(Barabas.Client.SyncedFile client_synced_file)
		{
			this.client_synced_file = client_synced_file;
		}
		
		public string get_name()
		{
			return client_synced_file.display_name;
		}
		
		public string get_mimetype()
		{
			return client_synced_file.mimetype;
		}
		
		public int64 get_remote_id()
		{
			return client_synced_file.ID;
		}
		
		public void tag(string tag)
		{
		}
		
		public void untag(string tag)
		{
		}
		
		public string[] tags()
		{
			return {};
		}
	}
}
