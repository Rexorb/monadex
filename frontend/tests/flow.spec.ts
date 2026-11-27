import { test, expect } from '@playwright/test'
import { randomBytes } from 'node:crypto'

// Requer backend + PostgreSQL com catálogo real e Vite com proxy /api.
// Cria uma conta de demonstração no banco configurado para o backend.
test('cadastro, login, recompensa, booster, coleção, expansões e logout', async ({ page }) => {
  const pageErrors: string[] = []
  const consoleErrors: string[] = []
  page.on('pageerror', (error) => pageErrors.push(error.message))
  page.on('console', (message) => { if (message.type() === 'error') consoleErrors.push(message.text()) })
  const username = `demo_fe_${randomBytes(5).toString('hex')}`
  const password = randomBytes(20).toString('hex')

  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Entre no Monadex' })).toBeVisible()
  await page.getByRole('link', { name: 'Cadastre-se' }).click()
  await page.getByLabel('Nome de usuário').fill(username)
  await page.getByLabel('Senha', { exact: true }).fill(password)
  await page.getByLabel('Confirmar senha').fill(password)
  await page.getByRole('button', { name: 'Criar conta' }).click()
  await expect(page.getByRole('heading', { name: new RegExp(username) })).toBeVisible()
  await page.getByRole('button', { name: 'Sair' }).click()
  await expect(page.getByRole('heading', { name: 'Entre no Monadex' })).toBeVisible()

  await page.getByLabel('Nome de usuário').fill(username)
  await page.getByLabel('Senha', { exact: true }).fill(password)
  await page.getByRole('button', { name: 'Entrar', exact: true }).click()
  await expect(page.getByRole('heading', { name: new RegExp(username) })).toBeVisible()
  await expect(page.getByText('Prontos para abrir')).toBeVisible()
  await page.getByRole('button', { name: 'Receber booster gratuito' }).click()
  await expect(page.getByText('Booster de hoje recebido')).toBeVisible()
  await page.screenshot({ path: '/tmp/opencode/monadex-dashboard-desktop.png', fullPage: true })

  await page.getByRole('link', { name: 'Boosters', exact: true }).click()
  await expect(page.getByText('1 disponíveis')).toBeVisible()
  await page.getByRole('button', { name: 'Abrir booster' }).click()
  await expect(page.getByRole('heading', { name: 'Suas seis cartas' })).toBeVisible()
  await expect(page.locator('.page-section').first().locator('.card-tile')).toHaveCount(6)
  await expect(page.getByText('0 disponíveis')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Abrir booster' })).toBeDisabled()

  await page.getByRole('link', { name: 'Minha coleção', exact: true }).click()
  await expect(page.getByText('215 no catálogo')).toBeVisible()
  await page.getByRole('combobox', { name: 'Filtrar por raridade' }).selectOption('Rare')
  await expect(page.locator('.card-tile').first()).toBeVisible()
  await page.getByRole('combobox', { name: 'Filtrar por raridade' }).selectOption('')
  await expect.poll(() => page.locator('.card-tile img').first().evaluate((image) =>
    (image as HTMLImageElement).naturalWidth)).toBeGreaterThan(0)
  await page.getByRole('checkbox', { name: 'Somente adquiridas' }).check()
  await expect(page.locator('.card-tile').first()).toBeVisible()
  await page.waitForTimeout(300)
  await page.screenshot({ path: '/tmp/opencode/monadex-collection-desktop.png', fullPage: true })
  await page.getByRole('link', { name: 'Expansões', exact: true }).click()
  await expect(page.locator('.expansion-card')).toHaveCount(1)
  await page.locator('.expansion-card').click()
  await expect(page.getByRole('heading', { name: 'Todas as cartas' })).toBeVisible()
  await expect(page.locator('.card-tile').first()).toBeVisible()

  await page.setViewportSize({ width: 390, height: 844 })
  await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
  await page.getByRole('button', { name: 'Abrir menu' }).click()
  await page.getByRole('link', { name: 'Visão geral' }).click()
  await expect(page.getByRole('heading', { name: new RegExp(username) })).toBeVisible()
  await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
  await page.waitForTimeout(250) // Espera a transição discreta do menu antes da captura.
  await page.screenshot({ path: '/tmp/opencode/monadex-dashboard-mobile.png', fullPage: true })
  await page.setViewportSize({ width: 320, height: 700 })
  await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
  await page.setViewportSize({ width: 390, height: 844 })
  await page.getByRole('button', { name: 'Abrir menu' }).click()
  await page.getByRole('button', { name: 'Sair' }).click()
  await expect(page.getByRole('heading', { name: 'Entre no Monadex' })).toBeVisible()
  expect(pageErrors).toEqual([])
  // 401 é esperado ao verificar a sessão anônima no início e após o logout.
  expect(consoleErrors.filter((message) => !message.includes('status of 401 (Unauthorized)'))).toEqual([])
})

test('login inválido mostra erro sem expor detalhes', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Nome de usuário').fill(`absent_${randomBytes(4).toString('hex')}`)
  await page.getByLabel('Senha', { exact: true }).fill('senha-incorreta-de-exemplo')
  await page.getByRole('button', { name: 'Entrar', exact: true }).click()
  await expect(page.getByRole('alert')).toHaveText('Usuário ou senha incorretos.')
  await expect(page.getByRole('heading', { name: 'Entre no Monadex' })).toBeVisible()
})
