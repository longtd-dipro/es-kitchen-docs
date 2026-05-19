---
name: frontend-review
description: >-
  Code review chuyên sâu cho 2 frontend repo ESKITCHEN: es-kitchen-web-admin (E03 System Admin)
  và es-kitchen-web-company (E02 Company Admin). Cùng stack: React 19, Vite 7, Redux Toolkit v2,
  TanStack Query v5, Ant Design v6, react-router-dom v7, TailwindCSS v4.
  Trigger khi review code frontend/React/TypeScript, hỏi "code này đúng không",
  "review giúp mình", hoặc muốn check component/hook/store ESKITCHEN.
---

# ESKITCHEN — Frontend Code Review

## Mục tiêu

Review code React/TypeScript theo **đúng stack và domain** của từng repo ESKITCHEN.

---

## Bước 1: Xác định repo và domain

| Repo | Epic | Domain | Stack |
|---|---|---|---|
| `es-kitchen-web-admin` | E03 | System Admin — quản trị toàn hệ thống (160 functions) | React 19 / Vite 7 / RTK v2 / TanStack v5 / AntD v6 |
| `es-kitchen-web-company` | E02 | Company Admin — quản lý company, contract, order | React 19 / Vite 7 / RTK v2 / TanStack v5 / AntD v6 |

> **Cả hai repo CÙNG stack** — nhưng **khác nhau hoàn toàn về domain logic và routes**.
> Lỗi phổ biến: implement business logic của E03 System Admin vào E02 Company Admin và ngược lại.

---

## Checklist Review

### 1. Domain Boundary (KIỂM TRA ĐẦU TIÊN)

- [ ] Code ở đúng repo (E02 company ≠ E03 system)?
- [ ] Route path phù hợp với domain của repo?
- [ ] Không import business logic từ repo kia?

### 2. State Management

```tsx
// ✅ TanStack Query v5 — cho SERVER state (data fetch)
const { data, isLoading, isError } = useQuery({
  queryKey: ['orders', companyId, { page, status }],
  queryFn: () => orderApi.getOrders(companyId, { page, status }),
  staleTime: 5 * 60 * 1000,
});

const mutation = useMutation({
  mutationFn: orderApi.createOrder,
  onSuccess: () => queryClient.invalidateQueries({ queryKey: ['orders'] }),
  onError: (error) => toast.error(error.message),
});

// ❌ Sai: TanStack Query v4 positional syntax
const { data } = useQuery(['orders'], () => fetchOrders()); // v4 — sai

// ✅ Redux Toolkit v2 — chỉ cho CLIENT state (auth, selections, UI)
const authSlice = createSlice({
  name: 'auth',
  initialState: { user: null as User | null },
  reducers: { setUser: (state, action: PayloadAction<User | null>) => { state.user = action.payload; } },
});

// ❌ Sai: Dùng Redux để cache server data
dispatch(setOrders(await fetchOrders())); // dùng TanStack Query thay vì Redux cho server data
```

- [ ] TanStack Query v5 object syntax `useQuery({ queryKey, queryFn })`?
- [ ] `queryKey` đủ dependencies tránh stale data?
- [ ] Redux chỉ cho client state (auth, UI selections) — không cache server data?
- [ ] `invalidateQueries` sau khi mutate thành công?

### 3. Routing — react-router-dom v7

```tsx
// ✅ v7 hooks
const navigate = useNavigate();
const { id } = useParams<{ id: string }>();
const [searchParams, setSearchParams] = useSearchParams();

// ❌ Đã bị removed
const history = useHistory(); // removed từ v6
import { Switch, Route } from 'react-router-dom'; // v5 — không có ở v7
```

- [ ] Không dùng `useHistory` (removed)?
- [ ] `useNavigate` thay vì history.push?
- [ ] `useParams` có type generic?

### 4. Ant Design v6

```tsx
// ✅ v6 pattern — kiểm tra breaking changes từ v5
// App wrapper cho message/modal hooks
import { App } from 'antd';
const { message, modal } = App.useApp();

// ✅ Table với TypeScript
const columns: ColumnsType<OrderRecord> = [
  { title: 'ID', dataIndex: 'id', key: 'id', sorter: true },
  { title: 'Trạng thái', dataIndex: 'status', render: (s) => <OrderStatusTag status={s} /> },
];

// ❌ Không dùng Form.Item validation của antd — dùng react-hook-form
<Form.Item name="companyCode" rules={[{ required: true }]}> {/* ❌ */}
```

- [ ] Kiểm tra breaking changes Ant Design v5 → v6 cho component đang dùng?
- [ ] Form validation qua react-hook-form + yup (không qua Form.Item rules)?
- [ ] `App.useApp()` cho message/modal/notification hooks?

### 5. Forms — react-hook-form v7 + yup

```tsx
// ✅ Đúng pattern
const schema = yup.object({
  companyCode: yup.string().required('Vui lòng nhập mã công ty'),
  quantity: yup.number().min(1).required(),
});

const { control, handleSubmit, formState: { errors } } = useForm<CreateOrderForm>({
  resolver: yupResolver(schema),
  defaultValues: { quantity: 1 },
});

// ✅ Controller cho Ant Design components
<Controller
  name="companyCode"
  control={control}
  render={({ field }) => <Input {...field} status={errors.companyCode ? 'error' : ''} />}
/>
```

- [ ] Schema yup có đủ validation rules?
- [ ] Error message hiển thị đúng từ `formState.errors`?
- [ ] `Controller` cho Ant Design components?

### 6. Component Patterns

```tsx
// ✅ Named export + Props interface
interface OrderCardProps { orderId: string; onStatusChange: (id: string) => void; }
export const OrderCard: React.FC<OrderCardProps> = ({ orderId, onStatusChange }) => { ... };

// ❌ Default export cho component chia sẻ
export default OrderCard;

// ❌ Class component
class OrderCard extends React.Component { ... }
```

- [ ] Named export?
- [ ] Props interface đặt tên `<Component>Props`?
- [ ] Không nhét nhiều component vào 1 file?

### 7. Hooks

```tsx
// ✅ useEffect dependencies đầy đủ
useEffect(() => { fetchOrder(orderId); }, [orderId]); // orderId trong deps

// ❌ Thiếu dependency
useEffect(() => { fetchOrder(orderId); }, []); // orderId missing

// ✅ Cleanup WebSocket/Socket.IO
useEffect(() => {
  socket.on('order:update', handleUpdate);
  return () => socket.off('order:update', handleUpdate); // cleanup
}, []);
```

- [ ] `useEffect` deps đầy đủ?
- [ ] Cleanup listeners trong return function?
- [ ] Custom hook bắt đầu bằng `use`?

### 8. TailwindCSS v4

```tsx
// ✅ v4 — config via @tailwindcss/postcss
// Không dùng tailwind.config.js cũ

// ✅ tailwind-merge cho conditional classes
import { twMerge } from 'tailwind-merge';
className={twMerge('px-4 py-2', isActive && 'bg-blue-500')}
```

- [ ] Không hard-code màu sắc — dùng Tailwind tokens?
- [ ] `tailwind-merge` cho conditional classes?

### 9. Security & Quality

- [ ] Không hard-code API URL — lấy từ `import.meta.env.VITE_*`?
- [ ] Không log token, password, payment data?
- [ ] TypeScript: không có `as any` không có lý do?
- [ ] Không `eslint-disable` không có comment giải thích?
- [ ] Input sanitization trước khi render HTML (tránh XSS)?

---

## Output Format

```
📋 FRONTEND REVIEW — [file/component]
Repo: es-kitchen-web-admin / es-kitchen-web-company | Epic: E03 / E02

🔴 Critical:
  - [Line X] Vấn đề → Fix cụ thể

🟡 Warning:
  - [Line X] Vấn đề → Đề xuất fix

🟢 OK:
  - [Điểm tốt]

💡 Suggestions (optional):
  - [Cải thiện không bắt buộc]

✅ Kết luận: Approve / Request Changes
```
