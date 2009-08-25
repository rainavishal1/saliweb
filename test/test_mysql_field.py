import unittest
from saliweb.backend import MySQLField

class MySQLFieldTest(unittest.TestCase):
    """Check MySQLField class"""

    def test_get_schema(self):
        """Check MySQLField.get_schema()"""
        field = MySQLField('name', 'VARCHAR(50)')
        self.assertEqual(field.get_schema(), 'name VARCHAR(50)')

if __name__ == '__main__':
    unittest.main()