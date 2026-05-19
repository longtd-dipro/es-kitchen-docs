---
description: Generate React component scaffold theo đúng pattern ESKITCHEN (web-admin E03 hoặc web-company E02). Dùng: /create-component <ComponentName> [admin|company]
---

Generate React component cho: **$ARGUMENTS**

## Bước 1 — Xác định repo và xem pattern hiện có

Nếu argument chứa "admin" → `es-kitchen-web-admin` (E03)
Nếu argument chứa "company" → `es-kitchen-web-company` (E02)
Nếu không rõ → hỏi user.

```
tilth_search(query: "useQuery")   ← xem TanStack Query pattern hiện tại
tilth_files(pattern: "src/components/**/*.tsx", path: "<repo>/")
```

## Bước 2 — Generate theo ESKITCHEN pattern

**Page Component** (nếu là route-level):
```tsx
// src/pages/<feature>/<ComponentName>.tsx
import { useQuery, useMutation } from '@tanstack/react-query';
import { App, Table } from 'antd';

interface <ComponentName>Props { /* ... */ }

export const <ComponentName>: React.FC<<ComponentName>Props> = () => {
  const { message } = App.useApp();

  const { data, isLoading } = useQuery({
    queryKey: ['<resource>', { /* params */ }],
    queryFn: () => <resource>Api.getList({ /* params */ }),
  });

  const mutation = useMutation({
    mutationFn: <resource>Api.create,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['<resource>'] });
      message.success('Thành công');
    },
  });

  return ( /* JSX */ );
};
```

**Shared Component** (nếu dùng lại nhiều nơi):
```tsx
// src/components/<ComponentName>/<ComponentName>.tsx
interface <ComponentName>Props {
  // props
}

export const <ComponentName>: React.FC<<ComponentName>Props> = ({ /* props */ }) => {
  return ( /* JSX */ );
};
```

**Custom Hook** (nếu cần logic riêng):
```tsx
// src/hooks/use<Feature>.ts
export const use<Feature> = () => {
  const { data, isLoading } = useQuery({ ... });
  return { data, isLoading };
};
```

## Bước 3 — Checklist sau generate

- [ ] Named export (không default export)?
- [ ] Props interface đặt tên `<Component>Props`?
- [ ] `App.useApp()` nếu dùng message/modal/notification?
- [ ] Đúng repo — không lẫn E02/E03 domain logic?
- [ ] Không hard-code `VITE_*` env variable?
