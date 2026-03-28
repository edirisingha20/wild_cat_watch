from django.db import migrations, models


def remove_duplicate_tokens(apps, schema_editor):
    """Keep only the most recent DeviceToken row for each token value."""
    DeviceToken = apps.get_model('sightings', 'DeviceToken')
    seen = set()
    for dt in DeviceToken.objects.order_by('-created_at'):
        if dt.token in seen:
            dt.delete()
        else:
            seen.add(dt.token)


class Migration(migrations.Migration):

    dependencies = [
        ('sightings', '0004_rename_sightings_l_latitud_71f8ec_idx_sightings_l_latitud_6a05ed_idx_and_more'),
    ]

    operations = [
        # Clean up any existing duplicates before adding the constraint.
        migrations.RunPython(remove_duplicate_tokens, migrations.RunPython.noop),
        migrations.AlterField(
            model_name='devicetoken',
            name='token',
            field=models.CharField(max_length=255, unique=True),
        ),
    ]
