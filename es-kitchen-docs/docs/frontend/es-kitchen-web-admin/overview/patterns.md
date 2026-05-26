# es-kitchen-web-admin — Patterns & Conventions

> Đọc file này trước khi viết code React mới cho E03. Follow pattern đang có — không tự refactor.

---

## HTTP Client Pattern

Tất cả API call đi qua singleton `API` — một instance của class `Requester`:

```typescript
// services/client/api.ts — KHÔNG sửa file này
class Requester {
  constructor() {
    const axiosInstance = axios.create({
      baseURL: serverConfig.api_server_url,
      withCredentials: true,
      headers: {
        'Content-Type': 'application/json',
        'Accept-Language': 'ja',          // ← Tiếng Nhật mặc định
      },
    });

    // Request interceptor: inject Bearer token
    axiosInstance.interceptors.request.use(async (config) => {
      const accessToken = getAccessToken();
      if (accessToken) config.headers['Authorization'] = `Bearer ${accessToken}`;
      config.headers['timezone'] = new Date().getTimezoneOffset();
      return config;
    });

    // Response interceptor: 401 → logout
    axiosInstance.interceptors.response.use(
      (res) => res.data,
      (error) => {
        if (error.response?.status === 401) store.dispatch(clearAuthState());
        return Promise.reject(error);
      }
    );
  }
}
const API = new Requester();
export default API;
```

---

## Service Layer Pattern

Mỗi domain có 1 service file trong `services/client/`. Service chỉ gọi `API`, không chứa React hook hay state:

```typescript
// services/client/company.service.ts
import API from './api';

export const companyService = {
  getCompanies: (params: GetCompaniesParams) =>
    API.get('/admin/companies', params),

  getCompanyDetail: (id: string) =>
    API.get(`/admin/companies/${id}`),

  createCompany: (data: CreateCompanyDto) =>
    API.post('/admin/companies', data),

  updateCompany: (id: string, data: UpdateCompanyDto) =>
    API.put(`/admin/companies/${id}`, data),

  importCsv: (file: File) => {
    const form = new FormData();
    form.append('file', file);
    return API.post('/admin/companies/import-csv', form, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  },
};
```

---

## TanStack Query Pattern (v5)

```typescript
// ✅ v5 syntax — queryKey + queryFn object
const { data, isLoading } = useQuery({
  queryKey: ['companies', filters],
  queryFn: () => companyService.getCompanies(filters),
});

// ✅ Mutation
const { mutate } = useMutation({
  mutationFn: (data: CreateCompanyDto) => companyService.createCompany(data),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['companies'] });
    message.success('Tạo thành công');
  },
});

// ❌ v4 syntax — KHÔNG dùng
useQuery(['companies', filters], () => companyService.getCompanies(filters));
```

**queryKey convention:**
```typescript
['companies']                    // list
['companies', { page, search }]  // list with filters
['companies', id]                // detail
['contracts', companyId]         // nested resource
```

---

## Redux Toolkit Pattern (v2)

RTK chỉ dùng cho **client state** — không dùng cho server data (dùng TanStack Query cho đó).

```typescript
// stores/reducers/auth.ts — pattern hiện có
const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    setAuthTokens(state, action: PayloadAction<{ accessToken: string; refreshToken: string }>) {
      setAuthCookies(action.payload);
      state.accessToken = action.payload.accessToken;
      state.refreshToken = action.payload.refreshToken;
      state.status = SESSION_STATUS.LOADING;
    },
    setCurrentUser(state, action: PayloadAction<AuthCurrentUser>) {
      state.user = action.payload;
      state.status = SESSION_STATUS.AUTHENTICATED;
    },
    clearAuthState(state) {
      clearAuthCookies();
      state.accessToken = null;
      state.refreshToken = null;
      state.user = null;
      state.status = SESSION_STATUS.UNAUTHENTICATED;
    },
  },
});
```

Auth token lưu **cookie** (không phải localStorage). Đọc/ghi qua `services/http/authToken.ts`.

---

## Auth Flow

```
App khởi động
  → bootstrapAuthStateFromCookies()    ← đọc cookie vào Redux
  → RequireAuth guard check status
      LOADING → fetch /admin/me → setCurrentUser()
      UNAUTHENTICATED → redirect /login
      AUTHENTICATED → render page

Login
  → POST /admin/auth/login
  → setAuthTokens({ accessToken, refreshToken })
  → cookies set + Redux update

401 response (bất kỳ request nào)
  → interceptor dispatch clearAuthState()
  → Redux status = UNAUTHENTICATED
  → RequireAuth redirect /login
```

---

## Routing Pattern

```typescript
// routes/index.tsx — createBrowserRouter
export const router = createBrowserRouter([
  {
    element: <PublicOnly />,    // redirect dashboard nếu đã auth
    children: [
      { path: ROUTE.LOGIN, element: withSuspense(<LoginPage />) },
    ],
  },
  {
    element: <RequireAuth />,   // redirect login nếu chưa auth
    children: [
      {
        element: <AuthLayout />,   // layout có sidebar + header
        children: [
          { path: ROUTE.DASHBOARD, element: withSuspense(<DashboardPage />) },
          { path: '/company-management/:id', element: withSuspense(<CompanyDetailPage />) },
        ],
      },
    ],
  },
]);
```

Route constants trong `constants/route.ts` — luôn dùng `ROUTE.xxx` thay vì string trực tiếp.

Lazy loading bắt buộc với `withSuspense()`:
```typescript
const CompanyDetailPage = lazy(() => import('@/pages/company-management/[id]/page'));
// Dùng: withSuspense(<CompanyDetailPage />)
```

---

## Page Structure Pattern

```
pages/<domain>/
├── page.tsx                    ← Entry point (list page)
├── [id]/
│   ├── page.tsx                ← Detail page entry
│   └── components/
│       ├── <Domain>PageContent.tsx   ← Main content
│       ├── shared/
│       │   └── <Domain>Header.tsx
│       └── tabs/
│           ├── <TabName>Tab.tsx
│           └── sections/
│               └── <Section>.tsx
```

Ví dụ thực tế: `pages/contract-management/[id]/components/tabs/pricing-payment/`

---

## Form Pattern (react-hook-form v7 + yup)

```typescript
// validation/schemas.ts — đặt yup schema tại đây
export const createCompanySchema = yup.object({
  name: yup.string().required('Tên công ty là bắt buộc'),
  code: yup.string().required().max(10),
});

// Trong component
const { register, handleSubmit, formState: { errors } } = useForm({
  resolver: yupResolver(createCompanySchema),
});
```

---

## Ant Design v6 — Lưu ý breaking changes

```typescript
// ❌ v5 — không dùng
import { PageHeader } from 'antd';

// ✅ v6
import { Flex, App } from 'antd';

// ✅ v6 — message/notification qua App context
const { message, notification } = App.useApp();

// ✅ Table pagination v6
<Table
  pagination={{ pageSize: 20, showSizeChanger: true }}
  rowKey="id"
/>
```

Khi dùng component Ant Design mới: kiểm tra docs v6 trước — API có thể khác v5.

---

## Component Conventions

```typescript
// ✅ Named export cho pages và components
export const CompanyDetailPage = () => { ... };

// ✅ Default export cho lazy-loaded pages
export default CompanyDetailPage;

// ✅ Type props rõ ràng
type CompanyCardProps = {
  company: Company;
  onEdit: (id: string) => void;
};
```

---

## useEffect — Dependency rules

```typescript
// ✅ deps đầy đủ
useEffect(() => {
  fetchData(filters);
}, [filters, fetchData]);

// ❌ bỏ sót dep — eslint sẽ warn
useEffect(() => {
  fetchData(filters);
}, []); // filters bị thiếu
```

Không `// eslint-disable-next-line` để bypass warning — fix đúng deps.
