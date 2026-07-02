from django.db import migrations


def seed_departments_and_positions(apps, schema_editor):
    Department = apps.get_model('users', 'Department')
    Position = apps.get_model('users', 'Position')

    department_positions = {
        'Wildlife Conservation Department': [
            'Wildlife Ranger',
            'Wildlife Guard',
            'Wildlife Officer',
            'Veterinary Surgeon (Wildlife Vet)',
            'Field Officer',
            'Field Supervisor',
        ],
        'Forest Department': [
            'Range Forest Officer (RFO)',
            'Forester',
            'Deputy Range Officer',
        ],
        'Estate Sector': [
            'Estate Superintendent',
            'Estate Manager',
        ],
    }

    for department_name, position_names in department_positions.items():
        department, _ = Department.objects.get_or_create(name=department_name)
        for position_name in position_names:
            Position.objects.get_or_create(
                department=department,
                name=position_name,
            )


def unseed_departments_and_positions(apps, schema_editor):
    Position = apps.get_model('users', 'Position')
    Department = apps.get_model('users', 'Department')
    Position.objects.all().delete()
    Department.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0003_department_position_user_department_user_position'),
    ]

    operations = [
        migrations.RunPython(seed_departments_and_positions, unseed_departments_and_positions),
    ]
