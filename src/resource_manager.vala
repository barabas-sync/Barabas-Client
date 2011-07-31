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
	public class ResourceManager<Resource>
	{
		private DBusConnection dbus_connection;
		private Gee.Map<int, Resource> mapped_resources;
		private int first_free;
		private string path;
		
		public ResourceManager(DBusConnection dbus_connection, string path)
		{
			this.first_free = 0;
			this.dbus_connection = dbus_connection;
			this.mapped_resources = new Gee.HashMap<int, Resource>();
			this.path = path;
		}
		
		public int add(Resource resource)
		{
			AResource a_resource = (AResource) resource;
			int id = find_free_id();
			mapped_resources.set(id, resource);
			a_resource.publish(path + "/" + id.to_string(), dbus_connection);
			
			//((AResource)resource).on_freed_all.connect(free_resource, resource);
			
			return id;
		}
		
		public Resource? get(int id)
		{
			return mapped_resources.get(id);
		}
		
		private void free_resource(Resource resource)
		{
			// TODO: implement
		}
		
		private int find_free_id()
		{
			int id = first_free;
			while (id in mapped_resources.keys)
			{
				id++;
			}
			first_free = id + 1;
			return id;
		}
	}
}
