<?php

namespace Database\Seeders;

/** Same people and dishes as the app's mock-up (exported by tool/export_mock_data.dart). */
final class DemoData
{
    public const PASSWORD = 'miski1234';

    public static function load(): array
    {
        return json_decode(file_get_contents(__DIR__.'/data/demo.json'), true, flags: JSON_THROW_ON_ERROR);
    }

    public static function email(string $handle): string
    {
        return "$handle@miski.test";
    }
}
