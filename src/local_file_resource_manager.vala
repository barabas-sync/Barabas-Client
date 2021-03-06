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
	public class LocalFileResourceManager
	{
		private static const string OBJECT_PATH = "/be/ac/ua/comp/Barabas/local_files";

		private Gee.Map<string, int> mapped_files;
		private ResourceManager<LocalFile> resource_manager;
		private DBusConnection dbus_connection;
		
		public delegate LocalFile CreateFileDelegate(string uri);
		public delegate void AccessFileDelegate(LocalFile file);
		
		public LocalFileResourceManager(DBusConnection dbus_connection)
		{
			this.resource_manager = new ResourceManager<LocalFile>(dbus_connection, OBJECT_PATH);
			this.mapped_files = new Gee.HashMap<string, int>();
			this.dbus_connection = dbus_connection;
		}
		
		public int get_id_for_uri(string uri, CreateFileDelegate create_file,
		                                      AccessFileDelegate access_file)
		{
			int object_id;
			if (uri in mapped_files.keys)
			{
				object_id = mapped_files[uri];
				access_file(resource_manager.get(object_id));
				return object_id;
			}
			else
			{
				LocalFile local_file = create_file(uri);
				object_id = resource_manager.add(local_file);
				local_file.unpublished.connect(file_unpublished);
				mapped_files.set(uri, object_id);
				return object_id;
			}
		}
		
		public int add(LocalFile local_file)
		{
			int object_id = resource_manager.add(local_file);
			mapped_files.set(local_file.get_uri(), object_id);
			return object_id;
		}
		
		private void file_unpublished(AResource resource)
		{
			LocalFile local_file = (LocalFile)resource;
			local_file.unpublished.disconnect(file_unpublished);
			mapped_files.unset(local_file.get_uri());
		}
	}
}
