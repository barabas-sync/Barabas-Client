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
			string the_path = path + "/" + id.to_string();
			stdout.printf("Publishing %s\n", the_path);
			
			try
			{
				a_resource.publish(the_path, dbus_connection);
			}
			catch (GLib.IOError error)
			{
				// FIXME: do something sensible
			}
			
			a_resource.unpublished.connect(free_resource);
			
			return id;
		}
		
		public Resource? get(int id)
		{
			return mapped_resources.get(id);
		}
		
		private void free_resource(AResource resource)
		{
			stdout.printf("Cleaning from list\n");
			foreach (int id in mapped_resources.keys)
			{
				if (mapped_resources[id] == resource)
				{
					mapped_resources.unset(id);
					stdout.printf("Found key and deleted %i\n", id);
					return;
					// Do not lower the first free key.
					// Reason is that we are not sure the objects really disappear
					// (Well, they are, but d-feet still shows them)
					// Overwriting does not seem a problem but it is cleaner
					// to just use a different ID.
					// When many searches are done, the ID will wrap around
					// and we just start over...
				}
			}
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
