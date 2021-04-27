/*
 * task_draw_images.c
 *
 *  Created on: Apr 25, 2021
 *      Author: icolb
 */

#include <main.h>
#include <log_movement.h>
#include <frog_movement.h>

TaskHandle_t Task_Draw_Images_Handle;

QueueHandle_t draw_queue;

typedef struct {
    bool log1;
    bool log2;
    bool log3;
} draw_msg_t;

/******************************************************************************
 * Draws images of frog and logs
 ******************************************************************************/
void Task_Draw_Images(void *pvParameters)
{
    Draw_Game_Base();
    draw_msg_t msg;
    BaseType_t status;

    draw_queue = xQueueCreate(5, sizeof(draw_msg_t));

    while (1)
    {
        // Wait for notification from queue
        status = xQueueReceive(draw_queue, &msg, portMAX_DELAY);

        // Take Draw semaphore
        xSemaphoreTake(Sem_Draw, portMAX_DELAY);

        // Draw Logs depending on which logs need to be updated
        // Log 1
        if (msg.log1)
        {
            lcd_draw_image(log_one.x_position, log_one.y_position,
                           froggerLogWidthPixels, froggerLogHeightPixels,
                           froggerLogBitmaps, LCD_COLOR_BROWN, LCD_COLOR_BLUE2);
        }

        // Log 2
        if (msg.log2)
        {
            lcd_draw_image(log_two.x_position, log_two.y_position,
                           froggerLogWidthPixels, froggerLogHeightPixels,
                           froggerLogBitmaps, LCD_COLOR_BROWN, LCD_COLOR_BLUE2);
        }

        // Log 3
        if (msg.log3)
        {
            lcd_draw_image(log_three.x_position, log_three.y_position,
                           froggerLogWidthPixels, froggerLogHeightPixels,
                           froggerLogBitmaps, LCD_COLOR_BROWN, LCD_COLOR_BLUE2);
        }

        // Draw Frog
        if (frog.on_Log)
        {
            // Frog is on a log, background color brown
            if (dark_mode)
            {
                // Dark mode, color frog yellow
                lcd_draw_image(frog.x_pos, frog.y_pos + 2, pixelFrogWidthPixels,
                               pixelFrogHeightPixels, pixelFrogBitmaps,
                               LCD_COLOR_YELLOW,
                               LCD_COLOR_BROWN);
            }
            else
            {
                // Light mode, color frog magenta
                lcd_draw_image(frog.x_pos, frog.y_pos + 2, pixelFrogWidthPixels,
                               pixelFrogHeightPixels, pixelFrogBitmaps,
                               LCD_COLOR_MAGENTA,
                               LCD_COLOR_BROWN);
            }
        }
        else if (frog.on_lilyPad)
        {
            // Frog is at start/end, background color green
            if (dark_mode)
            {
                // Dark mode, color frog yellow
                lcd_draw_image(frog.x_pos, frog.y_pos, pixelFrogWidthPixels,
                               pixelFrogHeightPixels, pixelFrogBitmaps,
                               LCD_COLOR_YELLOW,
                               LCD_COLOR_GREEN);
            }
            else
            {
                // Light mode, color frog magenta
                lcd_draw_image(frog.x_pos, frog.y_pos, pixelFrogWidthPixels,
                               pixelFrogHeightPixels, pixelFrogBitmaps,
                               LCD_COLOR_MAGENTA,
                               LCD_COLOR_GREEN);
            }
        }
        else
        {
            // frog is in water, background color blue
            if (dark_mode)
            {
                // Dark mode, color frog yellow
                lcd_draw_image(frog.x_pos, frog.y_pos, pixelFrogWidthPixels,
                               pixelFrogHeightPixels, pixelFrogBitmaps,
                               LCD_COLOR_YELLOW,
                               LCD_COLOR_BLUE2);
            }
            else
            {
                // Light mode, color frog magenta
                lcd_draw_image(frog.x_pos, frog.y_pos, pixelFrogWidthPixels,
                               pixelFrogHeightPixels, pixelFrogBitmaps,
                               LCD_COLOR_MAGENTA,
                               LCD_COLOR_BLUE2);
            }
        }

        // If frog's y_pos is that of log_one, redraw bottom start rectangle
        if (frog.left_ground)
        {
            lcd_draw_rectangle(64, xy_one, 132, block_width, LCD_COLOR_GREEN);
            lcd_draw_rectangle(64, xy_five, 132, block_width, LCD_COLOR_GREEN);
            // Set the bool of left_ground back to false
            frog.left_ground = false;
        }


        // Release Draw semaphore
        xSemaphoreGive(Sem_Draw);

        // Delay for 5 mS
        vTaskDelay(pdMS_TO_TICKS(5));
    }
}

/******************************************************************************
 * Draws the water and starting and ending blocks of the game
 ******************************************************************************/
void Draw_Game_Base(void)
{

    lcd_draw_rectangle(64, 64, 132, 132,
    LCD_COLOR_BLUE2);

    lcd_draw_rectangle(64, xy_one, 132, block_width, LCD_COLOR_GREEN);

    lcd_draw_rectangle(64, xy_five, 132, block_width, LCD_COLOR_GREEN);

}
