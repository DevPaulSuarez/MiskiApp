<?php

namespace App\Modules\Identity\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProfileRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        if ($this->has('handle')) {
            $this->merge(['handle' => mb_strtolower(ltrim(trim((string) $this->input('handle')), '@'))]);
        }
        if ($this->has('favorite_foods')) {
            $foods = collect((array) $this->input('favorite_foods'))
                ->map(fn ($f) => trim((string) $f))->filter()->unique(fn ($f) => mb_strtolower($f))->values()->all();
            $this->merge(['favorite_foods' => $foods]);
        }
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'min:2', 'max:80'],
            'handle' => ['sometimes', 'required', 'string', 'min:3', 'max:30', 'regex:/^[a-z0-9_.]+$/',
                Rule::unique('users', 'handle')->ignore($this->user()->id)],
            'bio' => ['sometimes', 'nullable', 'string', 'max:160'],
            'birthday' => ['sometimes', 'nullable', 'date', 'before:today'],
            'favorite_foods' => ['sometimes', 'array', 'max:20'],
            'favorite_foods.*' => ['string', 'max:60'],
            'favorite_category_ids' => ['sometimes', 'array'],
            'favorite_category_ids.*' => ['integer', 'exists:categories,id'],
        ];
    }

    public function messages(): array
    {
        return ['handle.regex' => 'El usuario solo puede tener letras minúsculas, números, punto y guion bajo.'];
    }
}
